defmodule Nexus.Identity.Events.UserRegistered do
  @moduledoc """
  Event emitted when a new user registers in the system.
  Follows Standard: Audit trail precision.
  """
  use TypedStruct

  @derive Jason.Encoder

  typedstruct enforce: true do
    field(:user_id, String.t(), doc: "A unique user identifier")
    field(:org_id, String.t(), doc: "Organization identifier")
    field(:email, String.t(), doc: "User's email")
    field(:name, String.t(), doc: "User's full name")
    field(:role, String.t(), doc: "User's role")
    field(:credential_id, String.t(), enforce: false, doc: "Biometric credential identifier")
    field(:cose_key, String.t(), enforce: false, doc: "Biometric public key (COSE format)")
  end
end
