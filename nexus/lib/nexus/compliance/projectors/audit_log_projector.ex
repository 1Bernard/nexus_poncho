defmodule Nexus.Compliance.Projectors.AuditLogProjector do
  @moduledoc """
  Audit projector for the Compliance domain.
  Projects all PEP screening events into compliance_audit_logs.

  Every event is recorded with:
  - event_id    — the event store's RecordedEvent UUID (idempotency key)
  - org_id      — the tenant this screening belongs to
  - event_type  — human-readable event name
  - payload     — the full event data (immutable)
  - actor_id    — the user being screened
  - recorded_at — when the event was stored in the event store

  The `on_conflict: :nothing` on event_id ensures safe re-projection.
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    repo: Nexus.Repo,
    name: "Compliance.AuditLogProjector"

  alias Ecto.Multi
  alias Nexus.Compliance.Events.{PEPCheckCompleted, PEPCheckInitiated}
  alias Nexus.Compliance.Projections.AuditLog

  project(%PEPCheckInitiated{} = event, metadata, fn multi ->
    insert_audit(multi, event, metadata, event.user_id, "pep_check_initiated")
  end)

  project(%PEPCheckCompleted{} = event, metadata, fn multi ->
    insert_audit(multi, event, metadata, event.user_id, "pep_check_completed")
  end)

  # ── Private ───────────────────────────────────────────────────────────────

  defp insert_audit(multi, event, metadata, actor_id, event_type) do
    attrs = %{
      id: Uniq.UUID.uuid7(),
      event_id: metadata.event_id,
      org_id: Map.get(event, :org_id),
      event_type: event_type,
      payload: Map.from_struct(event),
      actor_id: actor_id,
      recorded_at: metadata.created_at
    }

    Multi.insert(multi, :audit_log, AuditLog.changeset(%AuditLog{}, attrs),
      on_conflict: :nothing,
      conflict_target: :event_id
    )
  end
end
