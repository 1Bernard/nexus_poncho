defmodule Nexus.Identity.Events.SessionStarted do
  @moduledoc """
  Emitted when a user successfully authenticates via biometric fingerprint.
  Records which hardware credential was used — the permanent proof that
  this specific user was physically present at this moment.
  """
  @derive Jason.Encoder
  use TypedStruct

  typedstruct enforce: true do
    field(:session_id, String.t())
    field(:user_id, String.t())
    field(:org_id, String.t())
    field(:credential_id, String.t(), doc: "WebAuthn credential that authenticated this session")
    field(:expires_at, DateTime.t())
    field(:ip_address, String.t(), enforce: false)
    field(:user_agent, String.t(), enforce: false)
  end
end
