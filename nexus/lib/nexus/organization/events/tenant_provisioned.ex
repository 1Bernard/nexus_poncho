defmodule Nexus.Organization.Events.TenantProvisioned do
  @moduledoc """
  Event emitted when a new Tenant has been successfully provisioned.
  Follows Standard Chapter 11: The Elite Event.
  """
  use TypedStruct

  @derive Jason.Encoder

  @derive Jason.Encoder
  typedstruct do
    field(:org_id, String.t(), enforce: true)
    field(:name, String.t(), enforce: true)
    field(:initial_admin_email, String.t(), enforce: true)
    field(:provisioned_by, String.t(), enforce: true)
    field(:provisioned_at, DateTime.t(), enforce: true)
  end
end
