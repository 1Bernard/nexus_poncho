defmodule Nexus.Identity.Events.UserActivated do
  @moduledoc """
  Event emitted when a user is successfully activated following compliance clearance.
  Follows Standard: Audit trail precision.
  """
  use TypedStruct

  @derive Jason.Encoder

  typedstruct enforce: true do
    field(:user_id, String.t(), doc: "A unique user identifier")
    field(:org_id, String.t(), doc: "Organization identifier")
    field(:status, String.t(), doc: "Status after activation", default: "active")
  end
end
