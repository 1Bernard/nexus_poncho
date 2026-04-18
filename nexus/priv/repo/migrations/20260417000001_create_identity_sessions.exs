defmodule Nexus.Repo.Migrations.CreateIdentitySessions do
  use Ecto.Migration

  def change do
    create table(:identity_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, :binary_id, null: false
      add :org_id, :binary_id, null: false

      # The WebAuthn credential used to open this session —
      # permanent proof of physical biometric presence.
      add :credential_id, :string, null: false

      add :status, :string, null: false, default: "active"
      add :ip_address, :string
      add :user_agent, :string

      add :expires_at, :utc_datetime_usec, null: false
      add :started_at, :utc_datetime_usec, null: false
      add :expired_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec, inserted_at: :created_at, updated_at: false)
    end

    create index(:identity_sessions, [:user_id])
    create index(:identity_sessions, [:user_id, :status])
    create index(:identity_sessions, [:credential_id])
  end
end
