defmodule Nexus.Marketing.AccessRequest do
  use Ecto.Schema
  import Ecto.Changeset

  schema "access_requests" do
    field(:name, :string)
    field(:email, :string)
    field(:organization, :string)
    field(:job_title, :string)
    field(:treasury_volume, :string)
    field(:subsidiaries, :string)
    field(:message, :string)
    field(:status, :string, default: "pending")

    timestamps()
  end

  def changeset(access_request, attrs) do
    access_request
    |> cast(attrs, [
      :name,
      :email,
      :organization,
      :job_title,
      :treasury_volume,
      :subsidiaries,
      :message
    ])
    |> validate_required([
      :name,
      :email,
      :organization,
      :job_title,
      :treasury_volume,
      :subsidiaries
    ])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/, message: "must be a valid work email")
    |> validate_length(:name, min: 2, max: 100)
    |> validate_length(:organization, min: 2, max: 200)
    |> validate_inclusion(:treasury_volume, [
      "lt_10m",
      "10m_100m",
      "100m_500m",
      "500m_1b",
      "gt_1b"
    ])
    |> validate_inclusion(:subsidiaries, ["1_5", "6_20", "21_50", "51_100", "100_plus"])
  end
end
