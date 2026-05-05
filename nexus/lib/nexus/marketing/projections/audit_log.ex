defmodule Nexus.Marketing.Projections.AuditLog do
  @moduledoc """
  Immutable factual record of access request lifecycle events.
  Follows Standard Chapter 18: The Audit Log.

  Marketing is a pre-tenant pipeline, so org_id is always nil here.
  The audit trail covers the full journey: submitted → reviewed → approved/rejected → archived.
  """
  use Nexus.Schema

  schema "marketing_audit_logs" do
    field(:event_id, :binary_id)
    field(:event_type, :string)
    field(:payload, :map)
    field(:actor_id, :string)
    field(:recorded_at, :utc_datetime_usec)

    timestamps(type: :utc_datetime_usec, inserted_at: :created_at, updated_at: false)
  end

  def changeset(audit_log, attrs) do
    audit_log
    |> cast(attrs, [:id, :event_id, :event_type, :payload, :actor_id, :recorded_at])
    |> validate_required([:event_id, :event_type, :payload, :recorded_at])
  end
end
