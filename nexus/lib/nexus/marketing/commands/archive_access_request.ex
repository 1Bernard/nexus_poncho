defmodule Nexus.Marketing.Commands.ArchiveAccessRequest do
  @moduledoc "Command to archive a closed access request."
  use TypedStruct

  typedstruct enforce: true do
    field(:request_id, String.t())
    field(:archived_by, String.t(), enforce: false)
  end
end
