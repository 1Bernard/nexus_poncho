defmodule Nexus.Marketing.Projectors.AuditLogProjector do
  @moduledoc """
  Audit projector for the Marketing domain.
  Projects all access request lifecycle events into marketing_audit_logs.

  Every event is recorded with:
  - event_id    — the event store's RecordedEvent UUID (idempotency key)
  - event_type  — human-readable event name
  - payload     — the full event data (immutable)
  - actor_id    — admin who acted, or nil for initial submission
  - recorded_at — when the event was stored in the event store

  org_id is intentionally absent — marketing is a pre-tenant pipeline.
  The `on_conflict: :nothing` on event_id ensures safe re-projection.
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    repo: Nexus.Repo,
    name: "Marketing.AuditLogProjector"

  alias Ecto.Multi
  alias Nexus.Marketing.Projections.AuditLog

  alias Nexus.Marketing.Events.{
    AccessRequestApproved,
    AccessRequestArchived,
    AccessRequestRejected,
    AccessRequestReviewed,
    AccessRequestSubmitted
  }

  project(%AccessRequestSubmitted{} = event, metadata, fn multi ->
    insert_audit(multi, event, metadata, nil, "access_request_submitted")
  end)

  project(%AccessRequestReviewed{} = event, metadata, fn multi ->
    insert_audit(multi, event, metadata, event.reviewed_by, "access_request_reviewed")
  end)

  project(%AccessRequestApproved{} = event, metadata, fn multi ->
    insert_audit(multi, event, metadata, event.approved_by, "access_request_approved")
  end)

  project(%AccessRequestRejected{} = event, metadata, fn multi ->
    insert_audit(multi, event, metadata, event.rejected_by, "access_request_rejected")
  end)

  project(%AccessRequestArchived{} = event, metadata, fn multi ->
    insert_audit(multi, event, metadata, event.archived_by, "access_request_archived")
  end)

  # ── Private ───────────────────────────────────────────────────────────────

  defp insert_audit(multi, event, metadata, actor_id, event_type) do
    attrs = %{
      id: Uniq.UUID.uuid7(),
      event_id: metadata.event_id,
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
