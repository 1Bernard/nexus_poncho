defmodule Nexus.Repo.Migrations.CreateComplianceReadModels do
  use Ecto.Migration

  def change do
    create table(:compliance_screenings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, :binary_id, null: false
      add :org_id, :binary_id, null: false
      add :name, :string, null: false
      add :status, :string, null: false

      timestamps(type: :utc_datetime_usec, inserted_at: :created_at)
    end

    create index(:compliance_screenings, [:user_id])
    create index(:compliance_screenings, [:org_id])
    create index(:compliance_screenings, [:status])
  end
end
