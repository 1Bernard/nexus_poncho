defmodule Nexus.Marketing.AccessRequestSanctionsTest do
  @moduledoc """
  Integration tests for the sanctions screening lifecycle in the AccessRequest aggregate.

  The SanctionsWorker runs automatically and completes screening within milliseconds.
  These tests wait for the FINAL projection state ("clean" or "flagged") rather than
  the transient "pending" state, which is too brief to catch reliably via polling.

  The cooling-off guard (blocking review while "pending") is exercised in the aggregate
  unit test: Nexus.Marketing.AccessRequestAggregateTest.
  """
  use Nexus.DataCase

  @moduletag :no_sandbox

  import Commanded.Assertions.EventAssertions

  alias Nexus.App

  alias Nexus.Marketing.Commands.{
    ReviewAccessRequest,
    SubmitAccessRequest
  }

  alias Nexus.Marketing.Events.SanctionsScreeningInitiated
  alias Nexus.Marketing.Projections.AccessRequest
  alias Nexus.Repo

  # ── Full flow ─────────────────────────────────────────────────────────────

  describe "sanctions screening" do
    test "SanctionsScreeningInitiated event is emitted after submission" do
      request_id = Uniq.UUID.uuid7()

      :ok =
        App.dispatch(%SubmitAccessRequest{
          request_id: request_id,
          email: unique_email(),
          name: "Event Check Corp",
          organization: "Verified Holdings",
          job_title: "Treasurer",
          treasury_volume: "100m_500m",
          subsidiaries: "1_5"
        })

      assert_receive_event(App, SanctionsScreeningInitiated, fn event ->
        event.request_id == request_id
      end)
    end

    test "review succeeds after worker completes clean screening" do
      request_id = Uniq.UUID.uuid7()
      reviewer_id = Uniq.UUID.uuid7()

      :ok =
        App.dispatch(%SubmitAccessRequest{
          request_id: request_id,
          email: unique_email(),
          name: "Robert Clean",
          organization: "Clean Corp",
          job_title: "CFO",
          treasury_volume: "gt_1b",
          subsidiaries: "100_plus"
        })

      # Worker auto-completes with "clean" — wait for final projection state
      wait_until(fn ->
        case Repo.get(AccessRequest, request_id) do
          %{sanctions_screening: "clean"} -> {:ok, true}
          _ -> {:error, "waiting for sanctions_screening: clean"}
        end
      end)

      assert :ok =
               App.dispatch(%ReviewAccessRequest{
                 request_id: request_id,
                 reviewed_by: reviewer_id
               })

      wait_until(fn ->
        case Repo.get(AccessRequest, request_id) do
          %{status: "under_review"} -> {:ok, true}
          _ -> {:error, "waiting for status: under_review"}
        end
      end)
    end

    test "review is blocked when worker completes with flagged result" do
      request_id = Uniq.UUID.uuid7()

      :ok =
        App.dispatch(%SubmitAccessRequest{
          request_id: request_id,
          email: unique_email(),
          name: "Jane Corp Treasurer",
          organization: "Sanctioned Holdings",
          job_title: "Director",
          treasury_volume: "100m_500m",
          subsidiaries: "6_20"
        })

      # Worker auto-completes with "flagged" — wait for final projection state
      wait_until(fn ->
        case Repo.get(AccessRequest, request_id) do
          %{sanctions_screening: "flagged"} -> {:ok, true}
          _ -> {:error, "waiting for sanctions_screening: flagged"}
        end
      end)

      {:error, reason} =
        App.dispatch(%ReviewAccessRequest{
          request_id: request_id,
          reviewed_by: Uniq.UUID.uuid7()
        })

      assert reason == :sanctions_screening_flagged
    end
  end

  # ── Private ───────────────────────────────────────────────────────────────

  defp unique_email, do: "#{Uniq.UUID.uuid7()}@sanctions-test.nexus.com"

  defp wait_until(fun, retries \\ 30) do
    case fun.() do
      {:ok, val} ->
        val

      {:error, _} when retries > 0 ->
        Process.sleep(200)
        wait_until(fun, retries - 1)

      {:error, reason} ->
        flunk(reason)
    end
  end
end
