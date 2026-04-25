defmodule Nexus.Repo.Migrations.CreateOrganizationTenants do
  use Ecto.Migration

  def change do
    create table(:tenants, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :initial_admin_email, :string, null: false
      add :provisioned_by, :binary_id
      add :status, :string, null: false, default: "active"
      add :provisioned_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec, inserted_at: :created_at)
    end

    create index(:tenants, [:status])
  end
end
