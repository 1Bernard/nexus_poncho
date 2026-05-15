defmodule Nexus.Shared.Middleware.OpenTelemetry do
  @moduledoc false
  @behaviour Commanded.Middleware

  alias Commanded.Middleware.Pipeline
  alias Nexus.Shared.Tracing
  import Pipeline

  def before_dispatch(%Pipeline{command: command, metadata: metadata} = pipeline) do
    require OpenTelemetry.Tracer

    # Re-attach parent context (from LiveView inject_context or previous command in a saga).
    Tracing.extract_and_set_context(metadata)

    span_name = "Command.Dispatch.#{command.__struct__ |> Module.split() |> List.last()}"

    span = OpenTelemetry.Tracer.start_span(span_name)
    OpenTelemetry.Tracer.set_current_span(span)

    # Inject this span as parent so downstream events and saga commands are children.
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
