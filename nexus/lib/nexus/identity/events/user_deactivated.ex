defmodule Nexus.Identity.Events.UserDeactivated do
  @moduledoc "Emitted when a user is deactivated. Immutable audit record."
  @derive Jason.Encoder
  use TypedStruct

  typedstruct enforce: true do
    field(:user_id, String.t())
    field(:org_id, String.t())
    field(:reason, String.t(), enforce: false)
    field(:deactivated_by, String.t(), enforce: false)
  end
end
