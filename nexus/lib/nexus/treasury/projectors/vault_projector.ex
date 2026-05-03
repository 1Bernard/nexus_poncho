defmodule Nexus.Treasury.Projectors.VaultProjector do
  @moduledoc """
  Projector for the Treasury domain.
  Synchronizes business audits, idempotency records, and read models.
  Follows Standard Chapter 11: Projectors & Audit Precision.
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    repo: Nexus.Repo,
    name: "Treasury.VaultProjector"

  alias Decimal
  alias Ecto.Multi
  alias Nexus.Shared.Tracing
  alias Nexus.Treasury.Projections.AuditLog
  alias Nexus.Treasury.Events.{VaultCredited, VaultRegistered}
  alias Nexus.Treasury.Projections.IdempotencyKey
  alias Nexus.Treasury.Projections.Vault

  project(%VaultRegistered{} = event, metadata, fn multi ->
    require OpenTelemetry.Tracer
    Tracing.extract_and_set_context(metadata)

    OpenTelemetry.Tracer.with_span "Projector.Treasury.VaultRegistered" do
      multi
      |> Multi.insert(
        :vault,
        Vault.changeset(%Vault{}, %{
          id: event.vault_id,
          org_id: event.org_id,
          name: event.name,
          bank_name: event.bank_name,
          account_number: event.account_number,
          iban: event.iban,
          currency: event.currency,
          balance: Decimal.new(0),
          provider: event.provider,
          status: "active",
          daily_withdrawal_limit: event.daily_withdrawal_limit || Decimal.new(0),
          requires_multi_sig: event.requires_multi_sig
        }),
        on_conflict: :nothing,
        conflict_target: :id
      )
      |> audit_event(event, metadata)
      |> track_idempotency(metadata, "RegisterVault")
    end
  end)

  project(%VaultCredited{} = event, metadata, fn multi ->
    require OpenTelemetry.Tracer
    Tracing.extract_and_set_context(metadata)

    OpenTelemetry.Tracer.with_span "Projector.Treasury.VaultCredited" do
      multi
      |> Multi.update_all(:vault, query_vault(event.vault_id), inc: [balance: event.amount])
      |> audit_event(event, metadata)
      |> track_idempotency(metadata, "CreditVault")
    end
  end)

  # --- Private Helpers ---

  defp query_vault(vault_id) do
    import Ecto.Query
    from(v in Vault, where: v.id == ^vault_id)
  end

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
