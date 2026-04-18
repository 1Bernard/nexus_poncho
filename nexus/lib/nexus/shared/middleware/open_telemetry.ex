defmodule Nexus.Shared.Middleware.OpenTelemetry do
  @moduledoc """
  Commanded Middleware for distributed OpenTelemetry trace propagation.

  Bridge:
  1. Dispatcher Node: Injects current 'traceparent' into command metadata.
  2. Aggregate Node: Extracts 'traceparent' from metadata and attaches it to the execution context.
  """
  @behaviour Commanded.Middleware

  alias Commanded.Middleware.Pipeline
  alias Nexus.Shared.Tracing
  import Pipeline

  @doc """
  Handles trace propagation before the command is executed.
  """

  def before_dispatch(%Pipeline{command: command, metadata: metadata} = pipeline) do
    require OpenTelemetry.Tracer

    # Step 1: Link to Parent Context (if exists)
    # We extract and set the parent context so THIS span is a child of the predecessor.
    Tracing.extract_and_set_context(metadata)

    # Step 2: Start Local Execution Span
    # We determine the name based on whether we have a traceparent (Aggregate side) or not (Web side)
    # But to keep it simple and unified, we'll label it by its command.
    role =
      if Map.get(metadata, "traceparent") || Map.get(metadata, :traceparent),
        do: "Execute",
        else: "Dispatch"

    span_name = "Command.#{role}.#{command.__struct__ |> Module.split() |> List.last()}"

    span = OpenTelemetry.Tracer.start_span(span_name)
    OpenTelemetry.Tracer.set_current_span(span)

    # Step 3: Inject Current Span as Parent for the NEXT hop
    # This ensures that events or subsequent commands are children of THIS execution.
    metadata = Tracing.inject_context(metadata)

    pipeline
    |> assign(:otel_span, span)
    |> Map.put(:metadata, metadata)
  end

  def after_dispatch(%Pipeline{assigns: assigns} = pipeline) do
    case Map.get(assigns, :otel_span) do
      nil -> :ok
      span -> OpenTelemetry.Span.end_span(span)
    end

    pipeline
  end

  def after_failure(%Pipeline{assigns: assigns} = pipeline) do
    case Map.get(assigns, :otel_span) do
      nil ->
        :ok

      span ->
        OpenTelemetry.Span.set_status(
          span,
          OpenTelemetry.status(:error, "Command Execution Failure")
        )

        OpenTelemetry.Span.end_span(span)
    end

    pipeline
  end
end
