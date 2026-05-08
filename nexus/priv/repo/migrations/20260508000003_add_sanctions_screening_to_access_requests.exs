defmodule Nexus.Repo.Migrations.AddSanctionsScreeningToAccessRequests do
  use Ecto.Migration

  def change do
    alter table(:marketing_access_requests) do
      add(:sanctions_screening, :string, null: true)
    end

    create(index(:marketing_access_requests, [:sanctions_screening]))
  end
end
