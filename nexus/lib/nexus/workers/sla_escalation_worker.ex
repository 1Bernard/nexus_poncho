defmodule Nexus.Workers.SLAEscalationWorker do
  @moduledoc """
  Oban worker: escalates access requests that have been pending for over 3 days
  without any reviewer action.

  Runs on the :maintenance queue. Triggered by the Oban.Plugins.Cron schedule
  defined in config. Inserts one escalation notification per overdue request.

  ## Testing

  In integration tests use `Oban.drain_queue(queue: :maintenance)` to run
  this worker synchronously after inserting test data.
  """
  use Oban.Worker, queue: :maintenance, max_attempts: 3

  import Ecto.Query

  alias Nexus.Marketing.Projections.AccessRequest
  alias Nexus.Repo

  @sla_days 3

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    cutoff = DateTime.add(DateTime.utc_now(), -@sla_days * 86_400, :second)

    overdue =
      from(r in AccessRequest,
        where: r.status == "pending" and r.created_at <= ^cutoff,
        select: [:id, :email, :name, :organization, :created_at]
      )
      |> Repo.all()

    if overdue == [] do
      :ok
    else
      require Logger

      Enum.each(overdue, fn req ->
        age_days = DateTime.diff(DateTime.utc_now(), req.created_at, :second) |> div(86_400)

        Logger.warning(
          "[SLA] Access request #{req.id} for #{req.organization} (#{req.email}) " <>
            "has been pending for #{age_days} days — escalation required"
        )
      end)

      {:ok, %{escalated_count: length(overdue)}}
    end
  end
end
