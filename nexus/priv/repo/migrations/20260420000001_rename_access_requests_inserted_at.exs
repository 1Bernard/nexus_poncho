defmodule Nexus.Repo.Migrations.RenameAccessRequestsInsertedAt do
  use Ecto.Migration

  def change do
    rename table(:access_requests), :inserted_at, to: :created_at
  end
end
