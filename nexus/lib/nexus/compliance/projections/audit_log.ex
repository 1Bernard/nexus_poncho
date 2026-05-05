defmodule Nexus.Compliance.Projections.AuditLog do
  @moduledoc """
  Immutable factual record of compliance screening events.
  Follows Standard Chapter 18: The Audit Log.

  Stores PEP screening initiations and completions with the screened user
  as the actor. Critical for regulatory evidence and re-audit scenarios.
  """
  use Nexus.Schema

  schema "compliance_audit_logs" do
    field(:event_id, :binary_id)
    field(:org_id, :binary_id)
    field(:event_type, :string)
    field(:payload, :map)
    field(:actor_id, :string)
    field(:recorded_at, :utc_datetime_usec)

    timestamps(type: :utc_datetime_usec, inserted_at: :created_at, updated_at: false)
  end

  def changeset(audit_log, attrs) do
    audit_log
    |> cast(attrs, [:id, :event_id, :org_id, :event_type, :payload, :actor_id, :recorded_at])
    |> validate_required([:event_id, :org_id, :event_type, :payload, :recorded_at])
  end
end
