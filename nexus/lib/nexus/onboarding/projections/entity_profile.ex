defmodule Nexus.Onboarding.Projections.EntityProfile do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id

  schema "entity_profiles" do
    field(:org_id, :binary_id)
    field(:legal_name, :string)
    field(:country, :string)
    field(:registration_number, :string)
    field(:registered_address, :string)
    field(:tax_id, :string)
    field(:industry, :string)
    field(:beneficial_owners, {:array, :map}, default: [])
    field(:kyb_status, :string, default: "incomplete")
    field(:submitted_by, :binary_id)
    field(:reviewed_by, :binary_id)
    field(:reviewed_at, :utc_datetime_usec)

    timestamps(type: :utc_datetime_usec, inserted_at: :created_at)
  end

  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [
      :id,
      :org_id,
      :legal_name,
      :country,
      :registration_number,
      :registered_address,
      :tax_id,
      :industry,
      :beneficial_owners,
      :kyb_status,
      :submitted_by,
      :reviewed_by,
      :reviewed_at
    ])
    |> validate_required([
      :id,
      :org_id,
      :legal_name,
      :country,
      :registration_number,
      :registered_address,
      :industry
    ])
    |> unique_constraint(:org_id)
  end
end
