defmodule Nexus.Organization.Commands.ProvisionTenant do
  @moduledoc """
  Command to provision a new tenant organization.
  Follows Standard Chapter 8: The Elite Command.
  """
  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:org_id, String.t(), enforce: true)
    field(:name, String.t(), enforce: true)
    field(:initial_admin_email, String.t(), enforce: true)
    field(:provisioned_by, String.t(), enforce: true)
    field(:provisioned_at, DateTime.t(), enforce: true)
  end
end
