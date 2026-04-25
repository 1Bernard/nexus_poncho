defmodule Nexus.Marketing.Events.AccessRequestArchived do
  @moduledoc "Emitted when a closed access request is archived."
  @derive Jason.Encoder
  use TypedStruct

  typedstruct enforce: true do
    field(:request_id, String.t())
    field(:archived_by, String.t(), enforce: false)
  end
end
