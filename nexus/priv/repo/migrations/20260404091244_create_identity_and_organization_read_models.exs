defmodule Nexus.Repo.Migrations.CreateIdentityAndOrganizationReadModels do
  use Ecto.Migration

  def change do
    # Identity Audit Logs
    create table(:identity_audit_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event_id, :binary_id, null: false
      add :org_id, :binary_id, null: false
      add :event_type, :string, null: false
      add :payload, :map, null: false
      add :recorded_at, :utc_datetime_usec, null: false
      add :signature, :string

      timestamps(type: :utc_datetime_usec, inserted_at: :created_at)
    end

    create_if_not_exists index(:identity_audit_logs, [:org_id])
    create_if_not_exists index(:identity_audit_logs, [:event_type])

    # Identity Idempotency Keys
    create table(:identity_idempotency_keys, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :command_name, :string, null: false
      add :executed_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec, inserted_at: :created_at)
    end

    # Organization Audit Logs
    create table(:organization_audit_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event_id, :binary_id, null: false
      add :org_id, :binary_id, null: false
      add :event_type, :string, null: false
      add :payload, :map, null: false
      add :recorded_at, :utc_datetime_usec, null: false
      add :signature, :string

      timestamps(type: :utc_datetime_usec, inserted_at: :created_at)
    end

    create_if_not_exists index(:organization_audit_logs, [:org_id])

    # Organization Idempotency Keys
    create table(:organization_idempotency_keys, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :command_name, :string, null: false
      add :executed_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec, inserted_at: :created_at)
    end
  end
end
