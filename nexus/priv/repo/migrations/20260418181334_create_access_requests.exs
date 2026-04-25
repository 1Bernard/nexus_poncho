defmodule Nexus.Repo.Migrations.CreateAccessRequests do
  use Ecto.Migration

  def change do
    create table(:access_requests) do
      add :name, :string, null: false
      add :email, :string, null: false
      add :organization, :string, null: false
      add :job_title, :string, null: false
      add :treasury_volume, :string, null: false
      add :subsidiaries, :string, null: false
      add :message, :text
      add :status, :string, null: false, default: "pending"

      timestamps()
    end

    create index(:access_requests, [:email])
    create index(:access_requests, [:status])
  end
end
