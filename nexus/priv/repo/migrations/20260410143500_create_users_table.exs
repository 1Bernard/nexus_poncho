defmodule Nexus.Repo.Migrations.CreateUsersTable do
  use Ecto.Migration

  def change do
    create table(:identity_users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :org_id, :binary_id, null: false
      
      # Identity Details
      add :email, :string, null: false
      add :name, :string
      add :role, :string, null: false, default: "user"
      add :status, :string, null: false, default: "registered"
      
      # Biometric Credentials (Sovereign Standard)
      add :credential_id, :string
      add :cose_key, :text
      
      # Timestamps with microsecond precision
      timestamps(type: :utc_datetime_usec, inserted_at: :created_at)
    end

    create unique_index(:identity_users, [:email])
    create unique_index(:identity_users, [:credential_id])
    create index(:identity_users, [:org_id])
    create index(:identity_users, [:status])
  end
end
