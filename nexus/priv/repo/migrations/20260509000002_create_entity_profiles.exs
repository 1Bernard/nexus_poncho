defmodule Nexus.Repo.Migrations.CreateEntityProfiles do
  use Ecto.Migration

  def change do
    create table(:entity_profiles, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :org_id, :binary_id, null: false
      add :legal_name, :string, null: false
      add :country, :string, null: false, size: 2
      add :registration_number, :string, null: false
      add :registered_address, :text, null: false
      add :tax_id, :string, null: true
      add :industry, :string, null: false
      add :beneficial_owners, :jsonb, null: false, default: "[]"
      add :kyb_status, :string, null: false, default: "incomplete"
      add :submitted_by, :binary_id, null: true
      add :reviewed_by, :binary_id, null: true
      add :reviewed_at, :utc_datetime_usec, null: true

      timestamps(type: :utc_datetime_usec, inserted_at: :created_at)
    end

    create unique_index(:entity_profiles, [:org_id])
    create index(:entity_profiles, [:kyb_status])
  end
end
