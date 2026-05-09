defmodule Nexus.Repo.Migrations.CreateKybDocuments do
  use Ecto.Migration

  def change do
    create table(:kyb_documents, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :org_id, :binary_id, null: false
      add :document_type, :string, null: false
      add :file_key, :string, null: false
      add :file_name, :string, null: false
      add :file_size, :integer, null: true
      add :content_type, :string, null: true
      add :uploaded_by, :binary_id, null: false
      add :storage_bucket, :string, null: false, default: "nexus-kyb-documents"

      timestamps(type: :utc_datetime_usec, inserted_at: :created_at, updated_at: false)
    end

    create index(:kyb_documents, [:org_id])
    create index(:kyb_documents, [:org_id, :document_type])
  end
end
