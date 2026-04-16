defmodule Nexus.Repo.Migrations.CreateAccountingReadModels do
  use Ecto.Migration

  def change do
    # Standard Chapter 15: Read Models
    create table(:accounting_accounts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :org_id, :binary_id, null: false
      add :name, :string, null: false
      add :balance, :decimal, precision: 20, scale: 4, default: 0, null: false
      timestamps(type: :utc_datetime_usec, inserted_at: :created_at)
    end

    # Standard Chapter 18: The Audit Log
    create table(:accounting_audit_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event_id, :binary_id, null: false
      add :org_id, :binary_id, null: false
      add :event_type, :string, null: false
      add :payload, :map, null: false
      add :recorded_at, :utc_datetime_usec, null: false
      add :signature, :text

      timestamps(updated_at: false, type: :utc_datetime_usec, inserted_at: :created_at)
    end

    # Standard Chapter 8: Idempotency
    create table(:accounting_idempotency_keys, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :command_name, :string, null: false
      add :execution_result, :map
      add :executed_at, :utc_datetime_usec, null: false

      timestamps(updated_at: false, type: :utc_datetime_usec, inserted_at: :created_at)
    end

    # Commanded Projections Ecto: Version Tracking
    create table(:projection_versions, primary_key: false) do
      add :projection_name, :text, primary_key: true
      add :last_seen_event_number, :bigint

      timestamps(type: :utc_datetime_usec)
    end
  end
end
