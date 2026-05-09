defmodule Nexus.Identity.Projections.User do
  @moduledoc """
  Read model for Identity User.
  Follows Standard: Sovereign Identity.
  """
  use Nexus.Schema

  schema "identity_users" do
    field(:org_id, :binary_id)
    field(:email, :string)
    field(:name, :string)
    field(:role, :string)
    field(:status, :string)
    # Equinox platform staff role — nil for all customer users.
    # Values: "super_admin" | "platform_support" | nil
    field(:platform_role, :string)

    # Biometric Credentials
    field(:credential_id, :string)
    field(:cose_key, :string)

    # Terms acceptance
    field(:terms_accepted_at, :utc_datetime_usec)
    field(:terms_version, :string)

    timestamps(type: :utc_datetime_usec, inserted_at: :created_at)
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :id,
      :org_id,
      :email,
      :name,
      :role,
      :status,
      :platform_role,
      :credential_id,
      :cose_key,
      :terms_accepted_at,
      :terms_version
    ])
    |> validate_required([:id, :org_id, :email, :role, :status])
    |> validate_inclusion(:platform_role, ["super_admin", "platform_support"],
      message: "must be a valid platform role"
    )
    |> unique_constraint(:email)
    |> unique_constraint(:credential_id)
  end
end
