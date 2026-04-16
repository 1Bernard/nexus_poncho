defmodule Nexus.Identity.Events.BiometricEnrolled do
  @moduledoc """
  Event emitted when a user successfully anchors their biometric identity.
  """
  use TypedStruct

  @derive Jason.Encoder

  typedstruct enforce: true do
    field(:user_id, String.t(), doc: "User identifier")
    field(:org_id, String.t(), doc: "Organization identifier")
    field(:credential_id, String.t(), doc: "Biometric credential identifier")
    field(:cose_key, String.t(), doc: "Biometric public key (COSE format)")
  end
end
