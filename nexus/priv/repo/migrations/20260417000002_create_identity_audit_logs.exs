defmodule Nexus.Repo.Migrations.CreateIdentityAuditLogs do
  use Ecto.Migration

  @doc """
  The identity_audit_logs table was originally created in
  20260404091244_create_identity_and_organization_read_models.exs without
  actor_id or idempotency/compliance indexes. This migration adds them.
  """
  def change do
    alter table(:identity_audit_logs) do
      # Who performed the action (user_id, admin_id, or "system").
      add :actor_id, :string
    end

    # Idempotency: safe re-projection — skip if this event was already projected.
    create unique_index(:identity_audit_logs, [:event_id])

    # Compliance queries: actor activity, event type, time range.
    create_if_not_exists index(:identity_audit_logs, [:actor_id])
    create_if_not_exists index(:identity_audit_logs, [:event_type])
    create_if_not_exists index(:identity_audit_logs, [:recorded_at])
  end
end
