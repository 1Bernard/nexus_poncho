defmodule Nexus.Marketing.Projectors.AccessRequestProjector do
  @moduledoc """
  Projector for the Marketing domain.
  Synchronizes idempotency records and the access request read model.
  Follows Standard Chapter 11: Projectors & Audit Precision.
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    repo: Nexus.Repo,
    name: "Marketing.AccessRequestProjector"

  import Ecto.Query

  alias Ecto.Multi

  alias Nexus.Marketing.Events.{
    AccessRequestApproved,
    AccessRequestArchived,
    AccessRequestRejected,
    AccessRequestReviewed,
    AccessRequestSubmitted
  }

  alias Nexus.Marketing.Projections.AccessRequest
  alias Nexus.Marketing.Projections.IdempotencyKey

  require Logger

  project(%AccessRequestSubmitted{} = event, metadata, fn multi ->
    multi
    |> track_idempotency(metadata, "SubmitAccessRequest", %{request_id: event.request_id})
    |> submit_request(event, metadata)
  end)

  project(%AccessRequestReviewed{} = event, metadata, fn multi ->
    multi
    |> track_idempotency(metadata, "ReviewAccessRequest", %{request_id: event.request_id})
    |> update_request(event.request_id, reviewed_by: event.reviewed_by, status: "under_review")
  end)

  project(%AccessRequestApproved{} = event, metadata, fn multi ->
    multi
    |> track_idempotency(metadata, "ApproveAccessRequest", %{request_id: event.request_id})
    |> update_request(event.request_id,
      status: "approved",
      approved_by: event.approved_by,
      provisioned_user_id: event.provisioned_user_id,
      provisioned_org_id: event.provisioned_org_id
    )
  end)

  project(%AccessRequestRejected{} = event, metadata, fn multi ->
    multi
    |> track_idempotency(metadata, "RejectAccessRequest", %{request_id: event.request_id})
    |> update_request(event.request_id,
      status: "rejected",
      rejected_by: event.rejected_by,
      rejection_reason: event.reason
    )
  end)

  project(%AccessRequestArchived{} = event, metadata, fn multi ->
    multi
    |> track_idempotency(metadata, "ArchiveAccessRequest", %{request_id: event.request_id})
    |> update_request(event.request_id, status: "archived")
  end)

  # ── Private ───────────────────────────────────────────────────────────────

  defp submit_request(multi, event, metadata) do
    attrs = %{
      id: event.request_id,
      email: event.email,
      name: event.name,
      organization: event.organization,
      job_title: event.job_title,
      treasury_volume: event.treasury_volume,
      subsidiaries: event.subsidiaries,
      message: event.message,
      status: "pending",
      created_at: metadata.created_at,
      updated_at: metadata.created_at
    }

    changeset = AccessRequest.changeset(%AccessRequest{}, attrs)

    Multi.run(multi, :access_request, fn repo, _ ->
      case repo.insert(changeset, on_conflict: :nothing, conflict_target: :id) do
        {:ok, record} ->
          {:ok, record}

        {:error, %Ecto.Changeset{} = cs} ->
          Logger.warning("[Marketing] AccessRequestSubmitted skipped: #{inspect(cs.errors)}")
          {:ok, :conflict}
      end
    end)
  end

  defp update_request(multi, request_id, fields) do
    query = from(r in AccessRequest, where: r.id == ^request_id)
    updates = Keyword.merge(fields, updated_at: DateTime.utc_now())

    Multi.update_all(multi, :update_request, query, set: updates)
  end

  defp track_idempotency(multi, metadata, command_name, result) do
    id_key =
      Map.get(metadata, "idempotency_key") || Map.get(metadata, :idempotency_key) ||
        metadata.causation_id || metadata.event_id

    attrs = %{
      id: id_key,
      command_name: command_name,
      execution_result: result,
      executed_at: Nexus.Schema.utc_now()
    }

    changeset = IdempotencyKey.changeset(%IdempotencyKey{}, attrs)

    Multi.insert(multi, :"idempotency_#{metadata.event_id}", changeset,
      on_conflict: :nothing,
      conflict_target: :id
    )
  end
end
