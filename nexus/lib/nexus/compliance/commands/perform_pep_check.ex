defmodule Nexus.Compliance.Commands.PerformPEPCheck do
  @moduledoc """
  Command to initiate a Politically Exposed Person (PEP) check on a user identity.
  Follows Standard: Sovereign Onboarding.
  """
  defstruct [:screening_id, :user_id, :org_id, :name, :credential_id, :cose_key]

  @type t :: %__MODULE__{
          screening_id: String.t(),
          user_id: String.t(),
          org_id: String.t(),
          name: String.t(),
          credential_id: String.t(),
          cose_key: String.t()
        }
end
