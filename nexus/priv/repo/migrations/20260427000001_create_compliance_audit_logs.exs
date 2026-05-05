defmodule Nexus.Repo.Migrations.CreateComplianceAuditLogs do
  use Ecto.Migration

  def change do
    create table(:compliance_audit_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event_id, :binary_id, null: false
      add :org_id, :binary_id, null: false
      add :event_type, :string, null: false
      add :payload, :map, null: false
      add :actor_id, :string
      add :recorded_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec, inserted_at: :created_at, updated_at: false)
    end

    create unique_index(:compliance_audit_logs, [:event_id])
    create index(:compliance_audit_logs, [:org_id])
    create index(:compliance_audit_logs, [:actor_id])
    create index(:compliance_audit_logs, [:event_type])
    create index(:compliance_audit_logs, [:recorded_at])
  end
end
