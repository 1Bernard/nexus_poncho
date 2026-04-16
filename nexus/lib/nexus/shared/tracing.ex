defmodule Nexus.Shared.Tracing do
  @moduledoc """
  Robust OpenTelemetry utilities for the Nexus distributed cluster.
  Handles context propagation across process and network boundaries.
  """

  require Logger

  @traceparent "traceparent"

  @doc """
  Injects the current trace context into a metadata map.
  Returns the updated map with a "traceparent" string key.
  """
  def inject_context(metadata \\ %{}) do
    if Code.ensure_loaded?(:otel_propagator_text_map) do
      # Note: :otel_propagator_text_map.inject/1 is the stable high-level API.
      # It injects into a list of tuples which we then map to our metadata.
      case :otel_propagator_text_map.inject([]) do
        headers when is_list(headers) ->
          # Merge the OTel headers into our metadata map (preferring binary keys)
          Enum.reduce(headers, metadata, fn {field, value}, acc ->
            Map.put(acc, to_string(field), value)
          end)

        _ ->
          metadata
      end
    else
      metadata
    end
  rescue
    e ->
      Logger.error("[Tracing] Context injection failed: #{inspect(e)}")
      metadata
  end

  @doc """
  Extracts the trace context from a metadata map and attaches it to the current process.
  Supports both string and atom keys for resilience.
  """
  def extract_and_set_context(metadata) when is_map(metadata) do
    if Code.ensure_loaded?(:otel_propagator_text_map) do
      # Pull traceparent (and optional tracestate) from string or atom keys
      traceparent = Map.get(metadata, @traceparent) || Map.get(metadata, :traceparent)
      tracestate = Map.get(metadata, "tracestate") || Map.get(metadata, :tracestate)

      if traceparent do
        # Build the carrier with all W3C headers present
        carrier =
          [{@traceparent, to_string(traceparent)}]
          |> then(fn c ->
            if tracestate, do: [{"tracestate", to_string(tracestate)} | c], else: c
          end)

        # CORRECT API: extract_to/2 takes the CURRENT context and carrier,
        # and returns a NEW context enriched with the traceparent span.
        # extract/1 (which we were using before) returns an otel_ctx:token()
        # representing the OLD context — the exact opposite of what we need.
        current_ctx = :otel_ctx.get_current()
        new_ctx = :otel_propagator_text_map.extract_to(current_ctx, carrier)
        :otel_ctx.attach(new_ctx)
      else
        :ok
      end
    else
      :ok
    end
  rescue
    e ->
      Logger.error("[Tracing] Context extraction failed: #{inspect(e)}")
      :ok
  end

  @doc """
  Extracts context from a list of headers (e.g. from RabbitMQ).
  """
  def extract_from_headers(headers) when is_list(headers) do
    if Code.ensure_loaded?(:otel_propagator_text_map) do
      ctx = :otel_propagator_text_map.extract(headers)
      OpenTelemetry.Ctx.attach(ctx)
    else
      :ok
    end
  end

  @doc """
  Returns the current traceparent string, if active.
  Ensures it captures the context even inside active spans.
  """
  def get_current_traceparent do
    if Code.ensure_loaded?(:otel_propagator_text_map) do
      # Note: Use inject([]) to resolve current context and injector automatically.
      case :otel_propagator_text_map.inject([]) do
        headers when is_list(headers) ->
          case List.keyfind(headers, @traceparent, 0) do
            {@traceparent, tp} -> tp
            _ -> nil
          end

        _ ->
          nil
      end
    else
      nil
    end
  rescue
    e ->
      Logger.error("[Tracing] Failed to retrieve current traceparent: #{inspect(e)}")
      nil
  end
end
