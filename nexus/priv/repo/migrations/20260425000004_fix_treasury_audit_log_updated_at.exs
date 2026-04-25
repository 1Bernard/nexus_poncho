defmodule Nexus.Repo.Migrations.FixTreasuryAuditLogUpdatedAt do
  use Ecto.Migration

  @moduledoc """
  Audit logs are immutable append-only records. The TreasuryAuditLog schema
  uses `updated_at: false` so Ecto never sends that column. The original
  migration created it as NOT NULL, causing a null violation on every insert.
  Drop the column entirely — it has no meaning on an audit log.
  """

  def change do
    alter table(:treasury_audit_logs) do
      remove :updated_at
    end
  end
end
