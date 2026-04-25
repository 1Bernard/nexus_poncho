defmodule Nexus.Repo.Migrations.AddComplianceIdempotency do
  use Ecto.Migration

  def change do
    create table(:compliance_idempotency_keys, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :command_name, :string, null: false
      add :executed_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec, inserted_at: :created_at)
    end
  end
end
