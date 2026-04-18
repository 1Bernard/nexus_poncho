defmodule Nexus.Audit.Projections.PlatformAuditLog do
  @moduledoc """
  Cross-domain audit log schema.

  A single queryable timeline of every significant action across all domains —
  identity, treasury, accounting, compliance, and organization. Enables
  compliance officers to answer: "show me everything actor X did."

  Each row is keyed by event_id for idempotent re-projection.
  """
  use Nexus.Schema

  schema "platform_audit_logs" do
    field(:event_id, :binary_id)
    field(:org_id, :binary_id)
    field(:actor_id, :string)
    field(:domain, :string)
    field(:event_type, :string)
    field(:payload, :map)
    field(:recorded_at, :utc_datetime_usec)

    timestamps(type: :utc_datetime_usec, inserted_at: :created_at)
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [
      :id,
      :event_id,
      :org_id,
      :actor_id,
      :domain,
      :event_type,
      :payload,
      :recorded_at
    ])
    |> validate_required([:id, :event_id, :domain, :event_type, :payload])
  end
end
