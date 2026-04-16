defmodule Nexus.Telemetry.CommandTelemetry do
  @moduledoc """
  Implements the Commanded.Registration behaviour for injecting
  OpenTelemetry context into command metadata.
  """

  @doc """
  Injects the current OpenTelemetry trace context into the commanded metadata.
  This allows traces to span across the web node (dispatch) and aggregate node (execution).
  """
  alias Nexus.Shared.Tracing

  def inject_metadata(_command) do
    # Elite Standard: Use the centralized tracing bridge to inject the current context.
    # This automatically handles OTel 1.7.0 compliance and defensive context retrieval.
    Tracing.inject_context(%{})
  end
end
