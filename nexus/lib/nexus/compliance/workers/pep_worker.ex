defmodule Nexus.Compliance.Workers.PEPWorker do
  @moduledoc """
  Event Handler for Compliance Screening.
  Acts as an Anti-Corruption Layer (ACL) for external PEP/Sanctions APIs.
  Simulates a Multi-Factor check (Name + Biometric Uniqueness).
  """
  use Commanded.Event.Handler,
    application: Nexus.App,
    name: __MODULE__,
    consistency: :strong

  require Logger
  alias Nexus.Compliance.Events.{PEPCheckInitiated}
  alias Nexus.Compliance.Commands.CompletePEPCheck

  @doc """
  Handles the initiation of a PEP check by performing external screenings.
  """
  def handle(%PEPCheckInitiated{} = event, metadata) do
    # Elite Standard: Chain of Custody
    # Extract the incoming trace context to ensure the worker process is part of the lineage.
    require OpenTelemetry.Tracer
    Nexus.Shared.Tracing.extract_and_set_context(metadata)

    OpenTelemetry.Tracer.with_span "Worker.Compliance.PEPWorker" do
      Logger.info(
        "[Compliance] Processing PEP Check for User: #{event.user_id} (Name: #{event.name})"
      )

      Logger.debug("[Compliance] Raw Event Data: #{inspect(event)}")

      # Ensure biometric anchor is present
      if is_nil(event.cose_key) or event.cose_key == "" do
        Logger.error("[Compliance] Biometric Trust Anchor MISSING for User: #{event.user_id}")
        # We still proceed in test mode, but log the failure
      end

      # --- Step 1: Simulated External API Call (Req Standard) ---
      # Simulate a "Clean" result for most users
      status = if String.contains?(event.name, "Flagged"), do: "flagged", else: "clean"

      # --- Step 2: Biometric Uniqueness Check (The 'Sovereign' Check) ---
      cose_fingerprint = :crypto.hash(:sha256, event.cose_key || "") |> Base.encode16()

      Logger.info(
        "[Compliance] Performing Biometric Uniqueness Check for Credential: #{event.credential_id}"
      )

      Logger.info("[Compliance] COSE Fingerprint: #{cose_fingerprint}")

      # --- Step 3: Dispatch Completion Command with Proof ---
      cmd = %CompletePEPCheck{
        screening_id: event.screening_id,
        user_id: event.user_id,
        org_id: event.org_id,
        status: status,
        # We simulate the user's cryptographic proof signed during the screening flow
        biometric_proof: "v7_proof_" <> Uniq.UUID.uuid7()
      }

      # Dispatch back into the Nexus.App
      # Elite Logic: We MERGE the incoming metadata to preserve the traceparent and correlation IDs.
      metadata = Map.merge(metadata, %{"causation_id" => event.screening_id})

      case Nexus.dispatch(cmd, metadata: metadata) do
        {:ok, _} ->
          Logger.info("[Compliance] PEP Check Dispatch successful for #{event.user_id}")
          :ok

        {:error, reason} ->
          Logger.error("[Compliance] PEP Check Dispatch FAILED: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end
end
