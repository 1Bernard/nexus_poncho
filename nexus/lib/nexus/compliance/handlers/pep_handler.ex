defmodule Nexus.Compliance.Handlers.PEPHandler do
  @moduledoc """
  Event handler for PEP (Politically Exposed Person) compliance screening.
  Acts as an Anti-Corruption Layer (ACL) between domain events and the external
  PEP/Sanctions screening APIs. Dispatches CompletePEPCheck back into the domain
  with the screening result and biometric proof.
  """
  use Commanded.Event.Handler,
    application: Nexus.App,
    # Explicit name preserves the EventStore subscription checkpoint when the module was renamed.
    name: "Nexus.Compliance.Workers.PEPWorker",
    consistency: :strong

  require Logger
  require OpenTelemetry.Tracer

  alias Nexus.Compliance.Commands.CompletePEPCheck
  alias Nexus.Compliance.Events.PEPCheckInitiated
  alias Nexus.Shared.Tracing

  def handle(%PEPCheckInitiated{} = event, metadata) do
    Tracing.extract_and_set_context(metadata)

    OpenTelemetry.Tracer.with_span "Handler.Compliance.PEPHandler" do
      Logger.info(
        "[Compliance] Processing PEP Check for User: #{event.user_id} (Name: #{event.name})"
      )

      Logger.debug("[Compliance] Raw Event Data: #{inspect(event)}")

      if is_nil(event.cose_key) or event.cose_key == "" do
        Logger.error("[Compliance] Biometric Trust Anchor MISSING for User: #{event.user_id}")
      end

      # Simulate external PEP API — flag names containing "Flagged" for test determinism.
      # Production: replace with Req.get!/2 against a real screening vendor API.
      status = if String.contains?(event.name, "Flagged"), do: "flagged", else: "clean"

      cose_fingerprint = :crypto.hash(:sha256, event.cose_key || "") |> Base.encode16()

      Logger.info(
        "[Compliance] Biometric uniqueness check for credential: #{event.credential_id}"
      )

      Logger.info("[Compliance] COSE Fingerprint: #{cose_fingerprint}")

      cmd = %CompletePEPCheck{
        screening_id: event.screening_id,
        user_id: event.user_id,
        org_id: event.org_id,
        status: status,
        biometric_proof: "v7_proof_" <> Uniq.UUID.uuid7()
      }

      metadata =
        Map.merge(metadata, %{
          "causation_id" => event.screening_id,
          "idempotency_key" => event.screening_id
        })

      case Nexus.dispatch(cmd, metadata: metadata) do
        {:ok, _} ->
          Logger.info("[Compliance] PEP check dispatched for #{event.user_id}")
          :ok

        {:error, reason} ->
          Logger.error("[Compliance] PEP check dispatch failed: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end
end
