defmodule Nexus.Marketing.Commands.InitiateSanctionsScreening do
  @moduledoc "Triggers sanctions screening for an access request."
  use TypedStruct

  typedstruct enforce: true do
    field(:request_id, String.t())
    field(:email, String.t())
    field(:name, String.t())
    field(:organization, String.t())
  end
end
