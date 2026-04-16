defmodule Nexus.Repo.Migrations.StandardizeIdentityIdempotency do
  use Ecto.Migration

  def change do
    alter table(:identity_idempotency_keys) do
      add :execution_result, :map
    end

    alter table(:organization_idempotency_keys) do
      add :execution_result, :map
    end
  end
end
