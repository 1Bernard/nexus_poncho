defmodule Nexus.Marketing.AccessRequestSanctionsTest do
  @moduledoc """
  Integration tests for the sanctions screening lifecycle in the AccessRequest aggregate.

  Verifies:
  - Screening is automatically initiated via the process manager on submission
  - ReviewAccessRequest is blocked while screening is "pending"
  - ReviewAccessRequest is blocked when screening is "flagged"
  - ReviewAccessRequest proceeds when screening is "clean"
  """
  use Nexus.DataCase

  @moduletag :no_sandbox

  import Commanded.Assertions.EventAssertions

  alias Nexus.App

  alias Nexus.Marketing.Commands.{
    CompleteSanctionsScreening,
    ReviewAccessRequest,
    SubmitAccessRequest
  }

  alias Nexus.Marketing.Events.SanctionsScreeningInitiated
  alias Nexus.Marketing.Projections.AccessRequest
  alias Nexus.Repo

  # ── Cooling-off guard ─────────────────────────────────────────────────────

  describe "sanctions cooling-off guard" do
    test "reviewing a pending-screened request returns :sanctions_screening_in_progress" do
      request_id = Uniq.UUID.uuid7()

      :ok =
        App.dispatch(%SubmitAccessRequest{
          request_id: request_id,
          email: unique_email(),
          name: "Jane Corp Treasurer",
          organization: "Apex Holdings",
          job_title: "Group Treasurer",
          treasury_volume: "100m_500m",
          subsidiaries: "6_20"
        })

      # Wait for the process manager to initiate screening (sanctions_screening → "pending")
      wait_until(fn ->
        case Repo.get(AccessRequest, request_id) do
          %{sanctions_screening: "pending"} -> {:ok, true}
          _ -> {:error, "waiting for sanctions_screening: pending"}
        end
      end)

      {:error, reason} =
        App.dispatch(%ReviewAccessRequest{
          request_id: request_id,
          reviewed_by: Uniq.UUID.uuid7()
        })

      assert reason == :sanctions_screening_in_progress
    end

    test "review succeeds after screening completes with 'clean' result" do
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

      wait_until(fn ->
        case Repo.get(AccessRequest, request_id) do
          %{sanctions_screening: "pending"} -> {:ok, true}
          _ -> {:error, "waiting for screening pending"}
        end
      end)

      # Simulate screening worker completing with clean result
      :ok =
        App.dispatch(
          %CompleteSanctionsScreening{
            request_id: request_id,
            result: "clean"
          },
          metadata: %{"idempotency_key" => "#{request_id}:test_complete"}
        )

      wait_until(fn ->
        case Repo.get(AccessRequest, request_id) do
          %{sanctions_screening: "clean"} -> {:ok, true}
          _ -> {:error, "waiting for screening clean"}
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
          _ -> {:error, "waiting for under_review"}
        end
      end)
    end

    test "reviewing a flagged request returns :sanctions_screening_flagged" do
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

      wait_until(fn ->
        case Repo.get(AccessRequest, request_id) do
          %{sanctions_screening: "pending"} -> {:ok, true}
          _ -> {:error, "waiting for screening pending"}
        end
      end)

      # Manually complete with "flagged" (simulating a hit on the sanctions list)
      :ok =
        App.dispatch(
          %CompleteSanctionsScreening{
            request_id: request_id,
            result: "flagged"
          },
          metadata: %{"idempotency_key" => "#{request_id}:test_flag"}
        )

      wait_until(fn ->
        case Repo.get(AccessRequest, request_id) do
          %{sanctions_screening: "flagged"} -> {:ok, true}
          _ -> {:error, "waiting for screening flagged"}
        end
      end)

      {:error, reason} =
        App.dispatch(%ReviewAccessRequest{
          request_id: request_id,
          reviewed_by: Uniq.UUID.uuid7()
        })

      assert reason == :sanctions_screening_flagged
    end

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
  end

  # ── Private ───────────────────────────────────────────────────────────────

  defp unique_email, do: "#{Uniq.UUID.uuid7()}@sanctions-test.nexus.com"

  defp wait_until(fun, retries \\ 20) do
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
