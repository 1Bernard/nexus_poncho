defmodule Nexus.Identity.Projectors.AuditLogProjector do
  @moduledoc """
  Audit projector for the Identity domain.
  Projects all significant identity events into the identity_audit_logs table.

  Every event is recorded with:
  - event_id   — the event store's RecordedEvent UUID (idempotency key)
  - org_id     — the tenant this event belongs to
  - event_type — human-readable event name
  - payload    — the full event data (immutable)
  - actor_id   — who triggered the action (user, admin, or "system")
  - recorded_at — when the event was stored in the event store

  The `on_conflict: :nothing` on event_id ensures safe re-projection.
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    repo: Nexus.Repo,
    name: "Identity.AuditLogProjector"

  alias Ecto.Multi
  alias Nexus.Identity.Projections.AuditLog
  alias Nexus.Shared.Tracing

  alias Nexus.Identity.Events.{
    BiometricEnrolled,
    SessionExpired,
    SessionStarted,
    UserActivated,
    UserDeactivated,
    UserRegistered,
    UserRoleChanged
  }

  project(%UserRegistered{} = event, metadata, fn multi ->
    require OpenTelemetry.Tracer
    Tracing.extract_and_set_context(metadata)

    OpenTelemetry.Tracer.with_span "Projector.Identity.Audit.UserRegistered" do
      insert_audit(multi, event, metadata, event.user_id, "user_registered")
    end
  end)

  project(%BiometricEnrolled{} = event, metadata, fn multi ->
    require OpenTelemetry.Tracer
    Tracing.extract_and_set_context(metadata)

    OpenTelemetry.Tracer.with_span "Projector.Identity.Audit.BiometricEnrolled" do
      insert_audit(multi, event, metadata, event.user_id, "biometric_enrolled")
    end
  end)

  project(%UserActivated{} = event, metadata, fn multi ->
    require OpenTelemetry.Tracer
    Tracing.extract_and_set_context(metadata)

    OpenTelemetry.Tracer.with_span "Projector.Identity.Audit.UserActivated" do
      insert_audit(multi, event, metadata, event.user_id, "user_activated")
    end
  end)

  project(%UserDeactivated{} = event, metadata, fn multi ->
    require OpenTelemetry.Tracer
    Tracing.extract_and_set_context(metadata)

    OpenTelemetry.Tracer.with_span "Projector.Identity.Audit.UserDeactivated" do
      actor = event.deactivated_by || event.user_id
      insert_audit(multi, event, metadata, actor, "user_deactivated")
    end
  end)

  project(%UserRoleChanged{} = event, metadata, fn multi ->
    require OpenTelemetry.Tracer
    Tracing.extract_and_set_context(metadata)

    OpenTelemetry.Tracer.with_span "Projector.Identity.Audit.UserRoleChanged" do
      insert_audit(multi, event, metadata, event.changed_by, "user_role_changed")
    end
  end)

  project(%SessionStarted{} = event, metadata, fn multi ->
    require OpenTelemetry.Tracer
    Tracing.extract_and_set_context(metadata)

    OpenTelemetry.Tracer.with_span "Projector.Identity.Audit.SessionStarted" do
      insert_audit(multi, event, metadata, event.user_id, "session_started")
    end
  end)

  project(%SessionExpired{} = event, metadata, fn multi ->
    require OpenTelemetry.Tracer
    Tracing.extract_and_set_context(metadata)

    OpenTelemetry.Tracer.with_span "Projector.Identity.Audit.SessionExpired" do
      insert_audit(multi, event, metadata, event.user_id, "session_expired")
    end
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

    changeset = AuditLog.changeset(%AuditLog{}, attrs)

    Multi.insert(multi, :audit_log, changeset,
      on_conflict: :nothing,
      conflict_target: :event_id
    )
  end
end
