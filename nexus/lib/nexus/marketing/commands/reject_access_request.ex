defmodule Nexus.Marketing.Commands.RejectAccessRequest do
  @moduledoc "Command to reject an access request with an optional reason."
  use TypedStruct

  typedstruct enforce: true do
    field(:request_id, String.t())
    field(:rejected_by, String.t(), enforce: false)
    field(:reason, String.t(), enforce: false)
  end
end
