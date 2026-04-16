defmodule Nexus.Accounting.Projectors.AccountProjector do
  @moduledoc """
  Projector for the Accounting domain.
  Synchronizes business audits, idempotency records, and read models.
  Follows Standard Chapter 11: Projectors & Audit Precision.
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    repo: Nexus.Repo,
    name: "Accounting.AccountProjector"

  alias Ecto.Multi
  alias Nexus.Accounting.Events.AccountOpened
  alias Nexus.Accounting.Projections.Account
  alias Nexus.Accounting.Audit.AuditLog
  alias Nexus.Accounting.Idempotency.IdempotencyKey

  project(%AccountOpened{} = event, metadata, fn multi ->
    require OpenTelemetry.Tracer
    Nexus.Shared.Tracing.extract_and_set_context(metadata)

    OpenTelemetry.Tracer.with_span "Projector.Accounting.AccountOpened" do
      multi
      |> Multi.insert(
        :account,
        Account.changeset(%Account{}, %{
          id: event.account_id,
          org_id: event.org_id,
          name: event.name,
          balance: Decimal.new(0)
        }),
        on_conflict: :nothing,
        conflict_target: :id
      )
      |> audit_event(event, metadata)
      |> track_idempotency(metadata, "OpenAccount")
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
    attrs = %{
      id: metadata.causation_id || metadata.event_id,
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
