defmodule Nexus.Compliance.Aggregates.Screening do
  @moduledoc """
  Compliance Screening Aggregate.
  Handles PEP checks and other regulatory screening states.
  """

  require Logger

  defstruct [
    :id,
    :user_id,
    :org_id,
    :status,
    :biometric_proof
  ]

  alias __MODULE__, as: Screening
  alias Nexus.Compliance.Commands.{CompletePEPCheck, PerformPEPCheck}
  alias Nexus.Compliance.Events.{PEPCheckCompleted, PEPCheckInitiated}

  # --- Command Handlers ---

  def execute(%Screening{id: nil}, %PerformPEPCheck{} = cmd) do
    Logger.info("[Compliance] Initiating PEP Check: #{cmd.screening_id} for User: #{cmd.user_id}")

    %PEPCheckInitiated{
      screening_id: cmd.screening_id,
      user_id: cmd.user_id,
      org_id: cmd.org_id,
      name: cmd.name || "Automatic PEP Check",
      credential_id: cmd.credential_id,
      cose_key: cmd.cose_key
    }
  end

  def execute(%Screening{status: status}, %CompletePEPCheck{status: status}), do: []

  def execute(%Screening{status: "pending"}, %CompletePEPCheck{} = cmd) do
    # Elite Logic: We require a biometric proof signature to finalize a clean screening.
    if cmd.status == "clean" and
         (is_nil(cmd.biometric_proof) or String.trim(cmd.biometric_proof) == "") do
      {:error, "Biometric proof is required for clean PEP completion"}
    else
      %PEPCheckCompleted{
        screening_id: cmd.screening_id,
        user_id: cmd.user_id,
        org_id: cmd.org_id,
        status: cmd.status,
        biometric_proof: cmd.biometric_proof
      }
    end
  end

  def execute(%Screening{}, %CompletePEPCheck{}) do
    {:error, "invalid screening state"}
  end

  # --- State Transitions ---

  def apply(%Screening{} = state, %PEPCheckInitiated{} = event) do
    %Screening{
      state
      | id: event.screening_id,
        user_id: event.user_id,
        org_id: event.org_id,
        status: "pending"
    }
  end

  def apply(%Screening{} = state, %PEPCheckCompleted{} = event) do
    %Screening{
      state
      | status: event.status,
        biometric_proof: event.biometric_proof
    }
  end
end
