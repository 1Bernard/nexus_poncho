defmodule Nexus.Organization.Projections.Tenant do
  use Nexus.Schema

  schema "tenants" do
    field(:name, :string)
    field(:initial_admin_email, :string)
    field(:provisioned_by, :binary_id)
    field(:status, :string)
    field(:provisioned_at, :utc_datetime_usec)

    timestamps(type: :utc_datetime_usec, inserted_at: :created_at)
  end

  def changeset(tenant, attrs) do
    tenant
    |> cast(attrs, [:id, :name, :initial_admin_email, :provisioned_by, :status, :provisioned_at])
    |> validate_required([:id, :name, :initial_admin_email, :status])
  end
end
