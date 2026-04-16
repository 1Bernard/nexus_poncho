defmodule Nexus.Identity.Commands.RegisterUser do
  @moduledoc """
  Command to register a new user in the system.
  Follows Standard: Deterministic Engine.
  """
  use TypedStruct

  typedstruct enforce: true do
    field(:user_id, String.t(), doc: "User identifier")
    field(:org_id, String.t(), doc: "Organization identifier")
    field(:email, String.t(), doc: "User's email")
    field(:name, String.t(), doc: "User's full name")
    field(:role, String.t(), doc: "User's role")
    field(:credential_id, String.t(), enforce: false, doc: "Biometric credential identifier")
    field(:cose_key, String.t(), enforce: false, doc: "Biometric public key (COSE format)")
  end
end
