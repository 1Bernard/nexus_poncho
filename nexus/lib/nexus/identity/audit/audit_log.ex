defmodule Nexus.Identity.Audit.AuditLog do
  @moduledoc """
  Ecto Schema for the Audit Trail.
  Stores every domain event with user context for compliance and forensics.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id

  schema "identity_audit_logs" do
    field(:event_id, :binary_id)
    field(:org_id, :binary_id)
    field(:event_type, :string)
    field(:payload, :map)
    field(:actor_id, :string)
    field(:recorded_at, :utc_datetime_usec)

    timestamps(type: :utc_datetime_usec, inserted_at: :created_at)
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [
      :id,
      :event_id,
      :org_id,
      :event_type,
      :payload,
      :actor_id,
      :recorded_at
    ])
    |> validate_required([:id, :event_id, :event_type, :payload])
  end
end
