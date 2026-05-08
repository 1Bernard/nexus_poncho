defmodule Nexus.Marketing.Events.SanctionsScreeningInitiated do
  @moduledoc "Emitted when sanctions screening is queued for an access request."
  @derive Jason.Encoder
  use TypedStruct

  typedstruct enforce: true do
    field(:request_id, String.t())
    field(:email, String.t())
    field(:name, String.t())
    field(:organization, String.t())
  end
end
