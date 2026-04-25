defmodule Nexus.Marketing.Commands.ReviewAccessRequest do
  @moduledoc "Command to move an access request into active review."
  use TypedStruct

  typedstruct enforce: true do
    field(:request_id, String.t())
    field(:reviewed_by, String.t(), enforce: false)
  end
end
