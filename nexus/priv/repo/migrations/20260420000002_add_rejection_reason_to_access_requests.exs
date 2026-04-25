defmodule Nexus.Repo.Migrations.AddRejectionReasonToAccessRequests do
  use Ecto.Migration

  def change do
    alter table(:access_requests) do
      add :rejection_reason, :text
    end
  end
end
