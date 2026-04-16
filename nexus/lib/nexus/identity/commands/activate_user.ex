defmodule Nexus.Identity.Commands.ActivateUser do
  @moduledoc """
  Command to activate a user after successful compliance screening.
  Follows Standard: Deterministic Engine.
  """
  use TypedStruct

  typedstruct enforce: true do
    field(:user_id, String.t(), doc: "A unique user identifier")
    field(:org_id, String.t(), doc: "Organization identifier for routing")
  end
end
