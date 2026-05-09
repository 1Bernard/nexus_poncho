defmodule Nexus.Onboarding.Projections.KYBDocument do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id

  schema "kyb_documents" do
    field(:org_id, :binary_id)
    field(:document_type, :string)
    field(:file_key, :string)
    field(:file_name, :string)
    field(:file_size, :integer)
    field(:content_type, :string)
    field(:uploaded_by, :binary_id)
    field(:storage_bucket, :string)

    timestamps(type: :utc_datetime_usec, inserted_at: :created_at, updated_at: false)
  end

  def changeset(doc, attrs) do
    doc
    |> cast(attrs, [
      :id,
      :org_id,
      :document_type,
      :file_key,
      :file_name,
      :file_size,
      :content_type,
      :uploaded_by,
      :storage_bucket
    ])
    |> validate_required([:id, :org_id, :document_type, :file_key, :file_name, :uploaded_by])
  end
end
