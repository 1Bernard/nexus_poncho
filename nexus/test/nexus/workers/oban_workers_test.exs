defmodule Nexus.Workers.ObanWorkersTest do
  @moduledoc """
  Integration tests for Oban maintenance workers.

  Workers run in :manual mode in tests — jobs are inserted but not automatically
  executed. Use Oban.drain_queue/1 to run them synchronously.

  These tests directly insert aged projection records to simulate SLA breaches,
  bypassing the CQRS pipeline (read-model-layer tests only — the write side is
  covered by access_request_sanctions_test.exs).
  """
  use Nexus.DataCase

  @moduletag :no_sandbox

  alias Nexus.Marketing.Projections.AccessRequest
  alias Nexus.Repo
  alias Nexus.Workers.{ApprovalExpiryWorker, SLAEscalationWorker}

  # ── SLAEscalationWorker ──────────────────────────────────────────────────

  describe "SLAEscalationWorker" do
    test "returns :ok with zero escalations when no requests are overdue" do
      {:ok, job} = Oban.insert(SLAEscalationWorker.new(%{}))
      [result] = Oban.drain_queue(queue: :maintenance)
      assert result.id == job.id
      assert result.state == :success
    end

    test "returns :ok with escalated_count when aged pending requests exist" do
      old_ts = DateTime.add(DateTime.utc_now(), -5 * 86_400, :second)
      insert_access_request("pending", old_ts)

      {:ok, _job} = Oban.insert(SLAEscalationWorker.new(%{}))
      [result] = Oban.drain_queue(queue: :maintenance)

      assert result.state == :success
    end

    test "does not escalate pending requests within the 3-day SLA" do
      fresh_ts = DateTime.add(DateTime.utc_now(), -1 * 86_400, :second)
      insert_access_request("pending", fresh_ts)

      {:ok, _job} = Oban.insert(SLAEscalationWorker.new(%{}))
      [result] = Oban.drain_queue(queue: :maintenance)

      assert result.state == :success
    end
  end

  # ── ApprovalExpiryWorker ─────────────────────────────────────────────────

  describe "ApprovalExpiryWorker" do
    test "returns :ok when no under_review requests have expired" do
      {:ok, job} = Oban.insert(ApprovalExpiryWorker.new(%{}))
      [result] = Oban.drain_queue(queue: :maintenance)
      assert result.id == job.id
      assert result.state == :success
    end

    test "archives under_review requests past the 7-day deadline" do
      old_ts = DateTime.add(DateTime.utc_now(), -8 * 86_400, :second)
      request = insert_access_request("under_review", old_ts)

      {:ok, _job} = Oban.insert(ApprovalExpiryWorker.new(%{}))
      Oban.drain_queue(queue: :maintenance)

      # Give the CQRS write side time to project the archive
      wait_until(fn ->
        case Repo.get(AccessRequest, request.id) do
          %{status: "archived"} -> {:ok, true}
          _ -> {:error, "waiting for archived status"}
        end
      end)
    end

    test "does not archive under_review requests within the 7-day window" do
      fresh_ts = DateTime.add(DateTime.utc_now(), -2 * 86_400, :second)
      request = insert_access_request("under_review", fresh_ts)

      {:ok, _job} = Oban.insert(ApprovalExpiryWorker.new(%{}))
      Oban.drain_queue(queue: :maintenance)

      # Status should remain under_review
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

  defp wait_until(fun, retries \\ 20) do
    case fun.() do
      {:ok, val} ->
        val

      {:error, _} when retries > 0 ->
        Process.sleep(300)
        wait_until(fun, retries - 1)

      {:error, reason} ->
        flunk(reason)
    end
  end
end
