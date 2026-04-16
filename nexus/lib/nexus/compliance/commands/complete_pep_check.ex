defmodule Nexus.Compliance.Commands.CompletePEPCheck do
  @moduledoc """
  Command to finalize a PEP screening. 
  Requires biometric proof for "clean" status.
  """

  @derive Jason.Encoder
  defstruct [:screening_id, :user_id, :org_id, :status, :biometric_proof]

  @type t :: %__MODULE__{
          screening_id: String.t(),
          user_id: String.t(),
          org_id: String.t(),
          status: String.t(),
          biometric_proof: String.t()
        }
end
