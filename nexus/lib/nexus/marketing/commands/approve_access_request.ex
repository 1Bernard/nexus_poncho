defmodule Nexus.Marketing.Commands.ApproveAccessRequest do
  @moduledoc "Command to approve an access request and provision a user."
  use TypedStruct

  typedstruct enforce: true do
    field(:request_id, String.t())
    field(:approved_by, String.t(), enforce: false)
    field(:role, String.t())
    field(:provisioned_user_id, String.t())
    field(:provisioned_org_id, String.t())
  end
end
