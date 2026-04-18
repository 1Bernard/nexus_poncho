defmodule Nexus.Identity.Commands.DeactivateUser do
  @moduledoc """
  Command to deactivate a user. Used for offboarding, compliance violations,
  or administrative action. Produces a UserDeactivated event.
  Valid from any active status (invited, registered, active).
  """
  use TypedStruct

  typedstruct enforce: true do
    field(:user_id, String.t(), doc: "User to deactivate")
    field(:org_id, String.t(), doc: "Organization identifier")
    field(:reason, String.t(), enforce: false, doc: "Reason for deactivation (audit trail)")

    field(:deactivated_by, String.t(),
      enforce: false,
      doc: "Actor user_id who initiated deactivation"
    )
  end
end
