defmodule Nexus.Marketing.Events.SanctionsScreeningCompleted do
  @moduledoc "Emitted when sanctions screening result is recorded against an access request."
  @derive Jason.Encoder
  use TypedStruct

  typedstruct enforce: true do
    field(:request_id, String.t())
    # "clean" | "flagged"
    field(:result, String.t())
    field(:matched_list, String.t(), enforce: false)
  end
end
