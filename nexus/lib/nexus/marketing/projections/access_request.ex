defmodule Nexus.Marketing.Projections.AccessRequest do
  @moduledoc """
  Read model for Marketing Access Requests.
  Follows Standard Chapter 11: Projectors & Audit Precision.
  """
  use Nexus.Schema

  schema "marketing_access_requests" do
    field(:email, :string)
    field(:name, :string)
    field(:organization, :string)
    field(:job_title, :string)
    field(:treasury_volume, :string)
    field(:subsidiaries, :string)
    field(:message, :string)
    field(:status, :string, default: "pending")
    field(:rejection_reason, :string)
    field(:reviewed_by, :string)
    field(:approved_by, :string)
    field(:rejected_by, :string)
    field(:provisioned_user_id, :binary_id)
    field(:provisioned_org_id, :binary_id)

    timestamps(type: :utc_datetime_usec, inserted_at: :created_at)
  end

  def changeset(record, attrs) do
    record
    |> cast(attrs, [
      :id,
      :email,
      :name,
      :organization,
      :job_title,
      :treasury_volume,
      :subsidiaries,
      :message,
      :status,
      :rejection_reason,
      :reviewed_by,
      :approved_by,
      :rejected_by,
      :provisioned_user_id,
      :provisioned_org_id
    ])
    |> validate_required([
      :email,
      :name,
      :organization,
      :job_title,
      :treasury_volume,
      :subsidiaries
    ])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/, message: "must be a valid work email")
    |> validate_length(:name, min: 2, max: 100)
    |> validate_length(:organization, min: 2, max: 200)
    |> validate_inclusion(:treasury_volume, ~w(lt_10m 10m_100m 100m_500m 500m_1b gt_1b))
    |> validate_inclusion(:subsidiaries, ~w(1_5 6_20 21_50 51_100 100_plus))
  end
end
