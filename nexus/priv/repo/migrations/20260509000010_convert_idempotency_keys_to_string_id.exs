defmodule Nexus.Repo.Migrations.ConvertIdempotencyKeysToStringId do
  use Ecto.Migration

  @tables ~w(
    accounting_idempotency_keys
    compliance_idempotency_keys
    identity_idempotency_keys
    marketing_idempotency_keys
    organization_idempotency_keys
    treasury_idempotency_keys
  )

  def up do
    for table <- @tables do
      execute("ALTER TABLE #{table} ALTER COLUMN id TYPE text USING id::text")
    end
  end

  def down do
    for table <- @tables do
      execute("ALTER TABLE #{table} ALTER COLUMN id TYPE uuid USING id::uuid")
    end
  end
end
