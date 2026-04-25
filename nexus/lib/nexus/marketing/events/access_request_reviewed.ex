defmodule Nexus.Marketing.Events.AccessRequestReviewed do
  @moduledoc "Emitted when an admin begins reviewing an access request."
  @derive Jason.Encoder
  use TypedStruct

  typedstruct enforce: true do
    field(:request_id, String.t())
    field(:reviewed_by, String.t(), enforce: false)
  end
end
