defmodule Nexus.Identity.Events.UserRoleChanged do
  @moduledoc "Emitted when a user's role is changed. Immutable RBAC audit record."
  @derive Jason.Encoder
  use TypedStruct

  typedstruct enforce: true do
    field(:user_id, String.t())
    field(:org_id, String.t())
    field(:old_role, String.t())
    field(:new_role, String.t())
    field(:changed_by, String.t())
  end
end
