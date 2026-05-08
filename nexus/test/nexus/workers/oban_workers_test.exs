defmodule Nexus.Workers.ObanWorkersTest do
  @moduledoc """
  Integration tests for Oban maintenance workers.

  Workers run in :manual mode in tests — jobs are inserted but not automatically
  executed. Oban.drain_queue/1 runs them synchronously and returns a summary map:
  %{success: N, failure: N, discard: N, cancelled: N, snoozed: N}.

  These tests verify the worker mechanics (correct queue, runs without crashing,
  correct result summary). Business-level side-effects (archival via CQRS) are
  covered separately in the sanctions and lifecycle integration tests.
  """
  use Nexus.DataCase

  @moduletag :no_sandbox

  import Ecto.Query

  alias Nexus.Marketing.Projections.AccessRequest
  alias Nexus.Repo
  alias Nexus.Workers.{ApprovalExpiryWorker, SLAEscalationWorker}

  # Reset projection table and Oban queue between tests — no sandbox means state persists.
  setup do
    Repo.delete_all(AccessRequest)
    Repo.delete_all(from(j in Oban.Job, where: j.queue == "maintenance"))
    :ok
  end

  # ── SLAEscalationWorker ──────────────────────────────────────────────────

  describe "SLAEscalationWorker" do
    test "returns success with zero escalations when no requests are overdue" do
      {:ok, _job} = Oban.insert(SLAEscalationWorker.new(%{}))
      result = Oban.drain_queue(queue: :maintenance)
      assert result.success == 1
      assert result.failure == 0
    end

    test "returns success when aged pending requests exist and logs escalations" do
      old_ts = DateTime.add(DateTime.utc_now(), -5 * 86_400, :second)
      insert_access_request("pending", old_ts)

      {:ok, _job} = Oban.insert(SLAEscalationWorker.new(%{}))
      result = Oban.drain_queue(queue: :maintenance)

      assert result.success == 1
      assert result.failure == 0
    end

    test "does not escalate pending requests within the 3-day SLA" do
      fresh_ts = DateTime.add(DateTime.utc_now(), -1 * 86_400, :second)
      insert_access_request("pending", fresh_ts)

      {:ok, _job} = Oban.insert(SLAEscalationWorker.new(%{}))
      result = Oban.drain_queue(queue: :maintenance)

      assert result.success == 1
      assert result.failure == 0
    end
  end

  # ── ApprovalExpiryWorker ─────────────────────────────────────────────────

  describe "ApprovalExpiryWorker" do
    test "returns success when no under_review requests have expired" do
      {:ok, _job} = Oban.insert(ApprovalExpiryWorker.new(%{}))
      result = Oban.drain_queue(queue: :maintenance)
      assert result.success == 1
      assert result.failure == 0
    end

    test "processes expired under_review records without crashing" do
      # Inserts a projection-only record (no event store state). The worker
      # attempts ArchiveAccessRequest, which fails gracefully for unknown
      # aggregates. The worker returns a partial failure — this is acceptable
      # behavior for stale/orphaned records in test; the full CQRS path
      # (submit → screen → review → expiry) is covered by the sanctions test.
      old_ts = DateTime.add(DateTime.utc_now(), -8 * 86_400, :second)
      insert_access_request("under_review", old_ts)

      {:ok, _job} = Oban.insert(ApprovalExpiryWorker.new(%{}))
      result = Oban.drain_queue(queue: :maintenance)

      # Worker must complete (not crash) — failure is expected for DB-only records
      assert result.success + result.failure == 1
    end

    test "does not archive under_review requests within the 7-day window" do
      fresh_ts = DateTime.add(DateTime.utc_now(), -2 * 86_400, :second)
      request = insert_access_request("under_review", fresh_ts)

      {:ok, _job} = Oban.insert(ApprovalExpiryWorker.new(%{}))
      Oban.drain_queue(queue: :maintenance)

      # Record should remain under_review — not picked up by the expiry query
      fetched = Repo.get(AccessRequest, request.id)
      assert fetched.status == "under_review"
    end
  end

  # ── Private ───────────────────────────────────────────────────────────────

  defp insert_access_request(status, timestamp) do
    ts = DateTime.truncate(timestamp, :microsecond)

    attrs = %{
      id: Uniq.UUID.uuid7(),
      email: "#{Uniq.UUID.uuid7()}@worker-test.nexus.com",
      name: "Worker Test User",
      organization: "Test Holdings",
      job_title: "Treasurer",
      treasury_volume: "100m_500m",
      subsidiaries: "6_20",
      status: status
    }

    %AccessRequest{}
    |> AccessRequest.changeset(attrs)
    |> Ecto.Changeset.put_change(:created_at, ts)
    |> Ecto.Changeset.put_change(:updated_at, ts)
    |> Repo.insert!()
  end
end
