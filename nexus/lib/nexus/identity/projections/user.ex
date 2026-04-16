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
    field(:role, :string, default: "user")
    field(:status, :string, default: "registered")

    # Biometric Credentials
    field(:credential_id, :string)
    field(:cose_key, :string)

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:id, :org_id, :email, :name, :role, :status, :credential_id, :cose_key])
    |> validate_required([:id, :org_id, :email, :role, :status])
    |> unique_constraint(:email)
    |> unique_constraint(:credential_id)
  end
end
