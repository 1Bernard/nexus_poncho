defmodule Nexus.Organization.Projectors.TenantProjector do
  @moduledoc """
  Projector for the Organization domain.
  Synchronizes business audits, idempotency records, and read models.
  Follows Standard Chapter 11: Projectors & Audit Precision.
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    repo: Nexus.Repo,
    name: "Organization.TenantProjector"

  alias Ecto.Multi
  alias Nexus.Organization.Audit.AuditLog
  alias Nexus.Organization.Events.TenantProvisioned
  alias Nexus.Organization.Idempotency.IdempotencyKey
  alias Nexus.Organization.Projections.Tenant
  alias Nexus.Shared.Tracing

  project(%TenantProvisioned{} = event, metadata, fn multi ->
    require OpenTelemetry.Tracer
    Tracing.extract_and_set_context(metadata)

    OpenTelemetry.Tracer.with_span "Projector.Organization.TenantProvisioned" do
      multi
      |> Multi.insert(
        :tenant,
        Tenant.changeset(%Tenant{}, %{
          id: event.org_id,
          name: event.name,
          initial_admin_email: event.initial_admin_email,
          provisioned_by: event.provisioned_by,
          status: "active",
          provisioned_at: event.provisioned_at
        }),
        on_conflict: :nothing,
        conflict_target: :id
      )
      |> audit_event(event, metadata)
      |> track_idempotency(metadata, "ProvisionTenant")
    end
  end)

  # --- Private Helpers ---

  defp audit_event(multi, event, metadata) do
    attrs = %{
      id: Uniq.UUID.uuid7(),
      event_id: metadata.event_id,
      org_id: event.org_id,
      event_type: event.__struct__ |> Module.split() |> List.last(),
      payload: Map.from_struct(event),
      recorded_at: Nexus.Schema.utc_now()
    }

    changeset = AuditLog.changeset(%AuditLog{}, attrs)

    Multi.insert(multi, :"audit_#{metadata.event_id}", changeset,
      on_conflict: :nothing,
      conflict_target: :id
    )
  end

  defp track_idempotency(multi, metadata, command_name) do
    id_key =
      Map.get(metadata, "idempotency_key") || Map.get(metadata, :idempotency_key) ||
        metadata.causation_id || metadata.event_id

    attrs = %{
      id: id_key,
      command_name: command_name,
      executed_at: Nexus.Schema.utc_now()
    }

    changeset = IdempotencyKey.changeset(%IdempotencyKey{}, attrs)

    Multi.insert(multi, :"idempotency_#{metadata.event_id}", changeset,
      on_conflict: :nothing,
      conflict_target: :id
    )
  end
end
