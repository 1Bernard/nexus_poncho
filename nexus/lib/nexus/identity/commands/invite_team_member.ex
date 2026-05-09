defmodule Nexus.Identity.Commands.InviteTeamMember do
  use TypedStruct

  typedstruct enforce: true do
    field(:user_id, String.t())
    field(:org_id, String.t())
    field(:invited_by, String.t())
    field(:email, String.t())
    field(:name, String.t())
    field(:role, String.t())
  end
end
