defmodule Nexus.Marketing.Events.AccessRequestApproved do
  @moduledoc "Emitted when an access request is approved and a user is provisioned."
  @derive Jason.Encoder
  use TypedStruct

  typedstruct enforce: true do
    field(:request_id, String.t())
    field(:approved_by, String.t(), enforce: false)
    field(:role, String.t())
    field(:provisioned_user_id, String.t())
    field(:provisioned_org_id, String.t())
    field(:email, String.t())
    field(:name, String.t())
  end
end
