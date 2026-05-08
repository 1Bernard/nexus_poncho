defmodule Nexus.Workers.ApprovalExpiryWorker do
  @moduledoc """
  Oban worker: archives access requests that have been under_review for over 7 days
  without a final decision (approved or rejected).

  This prevents stale review queues and enforces the 7-day review SLA. A separate
  audit log entry is written for each auto-archived request.

  Runs on the :maintenance queue. Triggered by Oban.Plugins.Cron.

  ## Testing

  Use `Oban.drain_queue(queue: :maintenance)` after inserting aged under_review
  records to trigger synchronous execution in tests.
  """
  use Oban.Worker, queue: :maintenance, max_attempts: 3

  import Ecto.Query

  alias Nexus.App
  alias Nexus.Marketing.Commands.ArchiveAccessRequest
  alias Nexus.Marketing.Projections.AccessRequest
  alias Nexus.Repo

  @expiry_days 7
  @system_actor "system:approval_expiry"

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    cutoff = DateTime.add(DateTime.utc_now(), -@expiry_days * 86_400, :second)

    expired =
      from(r in AccessRequest,
        where: r.status == "under_review" and r.updated_at <= ^cutoff,
        select: [:id, :email, :organization]
      )
      |> Repo.all()

    if expired == [] do
      :ok
    else
      require Logger

      results =
        Enum.map(expired, fn req ->
          cmd = %ArchiveAccessRequest{
            request_id: req.id,
            archived_by: @system_actor
          }

          case App.dispatch(cmd,
                 metadata: %{"idempotency_key" => "#{req.id}:expiry_archive"}
               ) do
            :ok ->
              Logger.info(
                "[ApprovalExpiry] Auto-archived #{req.id} for #{req.organization} — review SLA exceeded"
              )

              :ok

            {:error, reason} ->
              Logger.error("[ApprovalExpiry] Failed to archive #{req.id}: #{inspect(reason)}")

              {:error, req.id}
          end
        end)

      errors = Enum.filter(results, &match?({:error, _}, &1))

      if errors == [] do
        {:ok, %{archived_count: length(expired)}}
      else
        {:error, "#{length(errors)} archival(s) failed"}
      end
    end
  end
end
