defmodule Nexus.LokiLogger do
  @moduledoc """
  OTP logger handler that ships Elixir Logger events to Loki.

  ## Architecture

  The OTP `:logger` framework calls `log/2` synchronously in the caller's process.
  To keep logging non-blocking, `log/2` casts the event to this GenServer, which
  batches entries in memory and flushes to Loki's HTTP push API on a timer or
  when the buffer reaches capacity.

  ## Labels

  Every log stream sent to Loki is labelled with:
  - `app`   — OTP app name (nexus or nexus_web)
  - `node`  — Erlang node name (nexus@node1.nexus, etc.)
  - `env`   — Mix environment (dev / prod)
  - `level` — log level (debug / info / warning / error)

  ## Configuration

  Started in the supervision tree with:

      {Nexus.LokiLogger, [
        loki_url: "http://loki:3100",
        app: "nexus",
        env: "dev"
      ]}

  Only starts when the `LOKI_URL` environment variable is set, so tests
  (which don't set it) never make outbound HTTP calls.
  """

  use GenServer

  @handler_id :nexus_loki
  @flush_ms 5_000
  @max_buffer 100
  @push_path "/loki/api/v1/push"

  # ---------------------------------------------------------------------------
  # :logger handler callbacks — called by the OTP logger framework.
  # These are module-level functions, NOT GenServer callbacks.
  # ---------------------------------------------------------------------------

  @doc false
  def log(%{level: level, msg: msg, meta: meta}, _handler_config) do
    # Guard: if the GenServer hasn't started yet (or has stopped), drop
    # silently. Never raise from a logger callback.
    case Process.whereis(__MODULE__) do
      nil -> :ok
      _pid -> GenServer.cast(__MODULE__, {:log, level, msg, meta})
    end
  end

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    loki_url = Keyword.get(opts, :loki_url, "http://loki:3100")
    app = Keyword.get(opts, :app, "nexus")
    env = Keyword.get(opts, :env, "dev")

    # Start :inets (Erlang's built-in HTTP client) if not already running.
    # Safe to call multiple times — returns {:error, {:already_started, _}} and
    # we ignore that.
    :inets.start()

    # Register this module as an OTP logger handler.  Done here (after the
    # GenServer is named) so that `log/2` can safely cast without a race.
    :logger.add_handler(@handler_id, __MODULE__, %{})

    schedule_flush()

    {:ok,
     %{
       buffer: [],
       loki_url: loki_url,
       app: app,
       env: env,
       node: to_string(node())
     }}
  end

  @impl true
  def terminate(_reason, _state) do
    :logger.remove_handler(@handler_id)
  end

  @impl true
  def handle_cast({:log, level, msg, meta}, state) do
    entry = build_entry(level, msg, meta)
    buffer = [entry | state.buffer]

    if length(buffer) >= @max_buffer do
      flush(buffer, state)
      {:noreply, %{state | buffer: []}}
    else
      {:noreply, %{state | buffer: buffer}}
    end
  end

  @impl true
  def handle_info(:flush, state) do
    unless state.buffer == [], do: flush(state.buffer, state)
    schedule_flush()
    {:noreply, %{state | buffer: []}}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp schedule_flush, do: Process.send_after(self(), :flush, @flush_ms)

  defp build_entry(level, msg, meta) do
    ts_ns = :os.system_time(:nanosecond)
    message = format_message(msg)
    suffix = format_meta(meta)
    {level, ts_ns, message <> suffix}
  end

  # Handle the three message formats the OTP logger emits.
  defp format_message({:string, iodata}),
    do: IO.iodata_to_binary(iodata)

  defp format_message({:report, report}) when is_map(report),
    do: inspect(report)

  defp format_message({:report, report}) when is_list(report) do
    Enum.map_join(report, " ", fn {k, v} -> "#{k}=#{inspect(v)}" end)
  end

  defp format_message({:format, fmt, args}) do
    :io_lib.format(fmt, args) |> IO.iodata_to_binary()
  end

  defp format_message(other), do: inspect(other)

  # Append structured metadata fields as key=value pairs.
  defp format_meta(meta) do
    meta
    |> Map.take([:module, :function, :line, :request_id])
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Enum.map_join("", fn {k, v} -> " #{k}=#{inspect(v)}" end)
  end

  # Group entries by level so each Loki stream has a consistent label set,
  # then push each group as a separate stream in one HTTP request.
  defp flush(buffer, %{loki_url: loki_url, app: app, env: env, node: node_name}) do
    streams =
      buffer
      |> Enum.group_by(fn {level, _, _} -> to_string(level) end)
      |> Enum.map(fn {level_str, entries} ->
        values =
          Enum.map(entries, fn {_, ts_ns, message} ->
            [to_string(ts_ns), message]
          end)

        %{
          stream: %{app: app, node: node_name, env: env, level: level_str},
          values: values
        }
      end)

    payload = Jason.encode!(%{streams: streams})
    url = String.to_charlist("#{loki_url}#{@push_path}")

    # Use :error_logger (Erlang's logger) for our own errors to avoid
    # recursively shipping them back through this handler.
    case :httpc.request(
           :post,
           {url, [], ~c"application/json", payload},
           [{:timeout, 5_000}],
           []
         ) do
      {:ok, {{_, status, _}, _, _}} when status in 200..299 ->
        :ok

      {:ok, {{_, status, _}, _, body}} ->
        :error_logger.error_msg(
          ~c"LokiLogger: push rejected status=~p body=~p~n",
          [status, body]
        )

      {:error, reason} ->
        :error_logger.error_msg(
          ~c"LokiLogger: push failed reason=~p~n",
          [reason]
        )
    end
  end
end
