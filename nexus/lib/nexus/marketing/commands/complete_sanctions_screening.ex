defmodule Nexus.Marketing.Commands.CompleteSanctionsScreening do
  @moduledoc "Records the result of a sanctions screening against an access request."
  use TypedStruct

  typedstruct enforce: true do
    field(:request_id, String.t())
    # "clean" | "flagged"
    field(:result, String.t())
    field(:matched_list, String.t(), enforce: false)
  end
end
