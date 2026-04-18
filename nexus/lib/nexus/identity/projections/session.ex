defmodule Nexus.Identity.Projections.Session do
  @moduledoc """
  Read model for an Identity Session.
  Each row is one biometric authentication event — a permanent record of
  who authenticated, when, with which credential, and from where.
  """
  use Nexus.Schema

  schema "identity_sessions" do
    field(:user_id, :binary_id)
    field(:org_id, :binary_id)
    field(:credential_id, :string)
    field(:status, :string, default: "active")
    field(:ip_address, :string)
    field(:user_agent, :string)
    field(:expires_at, :utc_datetime_usec)
    field(:started_at, :utc_datetime_usec)
    field(:expired_at, :utc_datetime_usec)
    timestamps(updated_at: false)
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :id,
      :user_id,
      :org_id,
      :credential_id,
      :status,
      :ip_address,
      :user_agent,
      :expires_at,
      :started_at,
      :expired_at
    ])
    |> validate_required([
      :id,
      :user_id,
      :org_id,
      :credential_id,
      :status,
      :expires_at,
      :started_at
    ])
  end
end
