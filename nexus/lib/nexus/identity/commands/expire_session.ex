defmodule Nexus.Identity.Commands.ExpireSession do
  @moduledoc """
  Command to explicitly terminate an active session.
  Used for logout, admin-forced revocation, or security incident response.
  """
  use TypedStruct

  typedstruct enforce: true do
    field(:session_id, String.t(), doc: "Session to expire")
    field(:user_id, String.t(), doc: "Owner of the session")
    field(:org_id, String.t(), doc: "Tenant context — required by TenantGate middleware")
  end
end
