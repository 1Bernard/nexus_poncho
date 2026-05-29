defmodule NexusWeb.TracingHooks do
  @moduledoc false

  # Bridges the Bandit WebSocket context gap.
  #
  # Bandit spawns a fresh GenServer process for the WebSocket connection,
  # discarding the HTTP plug process's OTel context. This module solves it
  # via two hooks:
  #
  #   1. live_session session: fn — runs in the HTTP plug process (OTel context
  #      IS active). Captures the current traceparent and injects it into the
  #      live_session session map so it survives the process boundary.
  #
  #   2. on_mount hook — runs in both HTTP (dead) and WebSocket (live) phases.
  #      Restores the captured traceparent into socket.assigns[:__otel_session_ctx].
  #
  # Usage in router:
  #
  #   live_session :authenticated,
  #     session: {NexusWeb.TracingHooks, :session_from_conn, []},
  #     on_mount: [
  #       {NexusWeb.UserAuth, :require_authenticated},
  #       NexusWeb.TracingHooks
  #     ] do
  #     ...
  #   end
  #
  # Usage at dispatch site in handle_event:
  #
  #   tracing_metadata = NexusWeb.TracingHooks.session_metadata(socket)
  #   App.dispatch(command, metadata: tracing_metadata)

  alias Nexus.Shared.Tracing

  @session_key "otel_traceparent"
  @assigns_key :__otel_session_ctx

  @doc """
  Called by live_session session: MFA in the HTTP plug process.
  Captures the current traceparent (available because HTTP OTel context is active)
  and injects it into the live session map so it crosses the process boundary.
  """
  def session_from_conn(_conn) do
    case Tracing.get_current_traceparent() do
      nil -> %{}
      tp -> %{@session_key => tp}
    end
  end

  @doc """
  on_mount hook. Restores the captured HTTP traceparent into socket assigns.
  When the WebSocket process starts, the session map (including the traceparent
  injected by session_from_conn/1) is available here — bridging the gap.
  """
  def on_mount(:default, _params, session, socket) do
    ctx =
      case Map.get(session, @session_key) do
        nil -> %{}
        tp -> %{"traceparent" => tp}
      end

    {:cont, Phoenix.Component.assign(socket, @assigns_key, ctx)}
  end

  @doc """
  Re-attaches the session OTel context and injects it as dispatch metadata.
  Replaces the plain `Tracing.inject_context(%{})` call at command dispatch sites.

  The re-attach makes the session traceparent the parent span, so the resulting
  Command.Dispatch.* span appears as a child of the session span in Tempo.
  """
  def session_metadata(%Phoenix.LiveView.Socket{} = socket) do
    ctx = Map.get(socket.assigns, @assigns_key, %{})
    Tracing.extract_and_set_context(ctx)
    Tracing.inject_context(%{})
  end
end
