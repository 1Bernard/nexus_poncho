defmodule Nexus.Compliance.Workers.SanctionsWorker do
  @moduledoc """
  Event handler for sanctions screening of institutional access requests.

  Listens for SanctionsScreeningInitiated, calls the external screening API
  (simulated), then dispatches CompleteSanctionsScreening back to the
  AccessRequest aggregate with the result.

  Follows the same ACL pattern as PEPWorker — isolation from external APIs,
  OTel span per screening, idempotency key set to request_id:sanctions_screen.
  """
  use Commanded.Event.Handler,
    application: Nexus.App,
    name: __MODULE__,
    consistency: :eventual

  require Logger
  require OpenTelemetry.Tracer

  alias Nexus.Marketing.Commands.CompleteSanctionsScreening
  alias Nexus.Marketing.Events.SanctionsScreeningInitiated
  alias Nexus.Shared.Tracing

  def handle(%SanctionsScreeningInitiated{} = event, metadata) do
    Tracing.extract_and_set_context(metadata)

    OpenTelemetry.Tracer.with_span "Worker.Compliance.SanctionsWorker" do
      Logger.info(
        "[Compliance] Sanctions screening for request #{event.request_id} (#{event.name}, #{event.organization})"
      )

      # Simulate external OFAC/UN/EU sanctions list check.
      # Production: replace with Req.get!/2 against a real screening vendor API.
      result = simulate_screening(event.name, event.organization)

      Logger.info("[Compliance] Sanctions result for #{event.request_id}: #{result}")

      cmd = %CompleteSanctionsScreening{
        request_id: event.request_id,
        result: result
      }

      metadata =
        Map.merge(metadata, %{
          "causation_id" => event.request_id,
          "idempotency_key" => "#{event.request_id}:sanctions_complete"
        })

      case Nexus.dispatch(cmd, metadata: metadata) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.error(
            "[Compliance] SanctionsWorker dispatch failed for #{event.request_id}: #{inspect(reason)}"
          )

          {:error, reason}
      end
    end
  end

  # Simulate screening: flag names/orgs containing "Sanctioned" for test determinism.
  defp simulate_screening(name, organization) do
    if String.contains?(name, "Sanctioned") or String.contains?(organization, "Sanctioned") do
      "flagged"
    else
      "clean"
    end
  end
end
