defmodule Nexus.Identity.Commands.UpdateUserRole do
  @moduledoc """
  Command to change a user's role. RBAC changes must flow through the domain
  as events — never direct Repo updates — to preserve the full audit trail.
  Only permitted for active users.
  """
  use TypedStruct

  typedstruct enforce: true do
    field(:user_id, String.t(), doc: "User whose role is being changed")
    field(:org_id, String.t(), doc: "Organization identifier")
    field(:new_role, String.t(), doc: "Role to assign (see NexusShared.Identity.Roles)")
    field(:changed_by, String.t(), doc: "Actor user_id who authorised the role change")
  end
end
