defmodule Nexus.Audit.Projectors.PlatformAuditProjector do
  @moduledoc """
  Cross-domain compliance audit projector.

  Subscribes to significant events from every domain and writes them to
  platform_audit_logs — a single timeline queryable by actor_id, org_id,
  domain, or time range.

  This answers the compliance question: "show me everything user X did
  across the entire platform."
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    repo: Nexus.Repo,
    name: "Audit.PlatformAuditProjector"

  alias Ecto.Multi
  alias Nexus.Audit.Projections.PlatformAuditLog

  # ── Identity ──────────────────────────────────────────────────────────────

  alias Nexus.Identity.Events.{
    BiometricEnrolled,
    SessionExpired,
    SessionStarted,
    UserActivated,
    UserDeactivated,
    UserRegistered,
    UserRoleChanged
  }

  project(%UserRegistered{} = e, meta, fn multi ->
    insert(multi, e, meta, "identity", "user_registered", e.user_id)
  end)

  project(%BiometricEnrolled{} = e, meta, fn multi ->
    insert(multi, e, meta, "identity", "biometric_enrolled", e.user_id)
  end)

  project(%UserActivated{} = e, meta, fn multi ->
    insert(multi, e, meta, "identity", "user_activated", e.user_id)
  end)

  project(%UserDeactivated{} = e, meta, fn multi ->
    insert(multi, e, meta, "identity", "user_deactivated", e.deactivated_by || e.user_id)
  end)

  project(%UserRoleChanged{} = e, meta, fn multi ->
    insert(multi, e, meta, "identity", "user_role_changed", e.changed_by)
  end)

  project(%SessionStarted{} = e, meta, fn multi ->
    insert(multi, e, meta, "identity", "session_started", e.user_id)
  end)

  project(%SessionExpired{} = e, meta, fn multi ->
    insert(multi, e, meta, "identity", "session_expired", e.user_id)
  end)

  # ── Organization ──────────────────────────────────────────────────────────

  alias Nexus.Organization.Events.TenantProvisioned

  project(%TenantProvisioned{} = e, meta, fn multi ->
    insert(multi, e, meta, "organization", "tenant_provisioned", e.provisioned_by)
  end)

  # ── Accounting ────────────────────────────────────────────────────────────

  alias Nexus.Accounting.Events.AccountOpened

  project(%AccountOpened{} = e, meta, fn multi ->
    insert(multi, e, meta, "accounting", "account_opened", nil)
  end)

  # ── Treasury ──────────────────────────────────────────────────────────────

  alias Nexus.Treasury.Events.{VaultCredited, VaultRegistered}

  project(%VaultRegistered{} = e, meta, fn multi ->
    insert(multi, e, meta, "treasury", "vault_registered", nil)
  end)

  project(%VaultCredited{} = e, meta, fn multi ->
    insert(multi, e, meta, "treasury", "vault_credited", nil)
  end)

  # ── Private ───────────────────────────────────────────────────────────────

  defp insert(multi, event, metadata, domain, event_type, actor_id) do
    attrs = %{
      id: Uniq.UUID.uuid7(),
      event_id: metadata.event_id,
      org_id: Map.get(event, :org_id),
      actor_id: actor_id,
      domain: domain,
      event_type: event_type,
      payload: Map.from_struct(event),
      recorded_at: metadata.created_at,
      created_at: metadata.created_at
    }

    Multi.insert(
      multi,
      :platform_audit_log,
      PlatformAuditLog.changeset(%PlatformAuditLog{}, attrs),
      on_conflict: :nothing,
      conflict_target: :event_id
    )
  end
end
