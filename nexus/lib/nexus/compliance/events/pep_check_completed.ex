defmodule Nexus.Compliance.Events.PEPCheckCompleted do
  @moduledoc """
  Event emitted when a PEP screening finalized.
  Includes the biometric proof captured during the gate.
  """
  use TypedStruct

  @derive Jason.Encoder

  typedstruct enforce: true do
    field(:screening_id, String.t())
    field(:user_id, String.t())
    field(:org_id, String.t())
    # "clean", "flagged"
    field(:status, String.t())

    # Cryptographic proof signature
    field(:biometric_proof, String.t())
  end
end
