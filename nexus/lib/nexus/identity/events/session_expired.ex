defmodule Nexus.Identity.Events.SessionExpired do
  @moduledoc "Emitted when a session is explicitly terminated (logout or admin revocation)."
  @derive Jason.Encoder
  use TypedStruct

  typedstruct enforce: true do
    field(:session_id, String.t())
    field(:user_id, String.t())
    field(:org_id, String.t())
  end
end
