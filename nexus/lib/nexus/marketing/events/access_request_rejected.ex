defmodule Nexus.Marketing.Events.AccessRequestRejected do
  @moduledoc "Emitted when an access request is rejected."
  @derive Jason.Encoder
  use TypedStruct

  typedstruct enforce: true do
    field(:request_id, String.t())
    field(:rejected_by, String.t(), enforce: false)
    field(:reason, String.t(), enforce: false)
  end
end
