defmodule Nexus.Repo.Migrations.MakeAuditLogOrgIdNullable do
  use Ecto.Migration

  def change do
    alter table(:identity_audit_logs) do
      modify :org_id, :binary_id, null: true
    end
  end
end
