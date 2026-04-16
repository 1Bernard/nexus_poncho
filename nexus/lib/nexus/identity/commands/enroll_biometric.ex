defmodule Nexus.Identity.Commands.EnrollBiometric do
  @moduledoc """
  Command to anchor biometric identity for an existing user.
  """
  use TypedStruct

  typedstruct enforce: true do
    field(:user_id, String.t(), doc: "User identifier")
    field(:org_id, String.t(), doc: "Organization identifier")
    field(:credential_id, String.t(), doc: "Biometric credential identifier")
    field(:cose_key, String.t(), doc: "Biometric public key (COSE format)")
  end
end
