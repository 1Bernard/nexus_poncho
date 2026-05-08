defmodule Nexus.Marketing.AccessRequestAggregateTest do
  @moduledoc """
  Unit tests for AccessRequest aggregate execute/2 clauses.

  Tests the cooling-off guards in isolation — no Commanded infrastructure,
  no event store, no async workers. Fast and deterministic.
  """
  use ExUnit.Case, async: true

  alias Nexus.Marketing.Aggregates.AccessRequest
  alias Nexus.Marketing.Commands.ReviewAccessRequest

  defp pending_request(overrides \\ %{}) do
    struct(
      AccessRequest,
      Map.merge(%{request_id: Uniq.UUID.uuid7(), status: "pending"}, overrides)
    )
  end

  defp review_cmd(request_id),
    do: %ReviewAccessRequest{request_id: request_id, reviewed_by: Uniq.UUID.uuid7()}

  describe "cooling-off guards" do
    test "review is blocked when sanctions_screening is pending" do
      state = pending_request(%{sanctions_screening: "pending"})

      assert {:error, :sanctions_screening_in_progress} =
               AccessRequest.execute(state, review_cmd(state.request_id))
    end

    test "review is blocked when sanctions_screening is flagged" do
      state = pending_request(%{sanctions_screening: "flagged"})

      assert {:error, :sanctions_screening_flagged} =
               AccessRequest.execute(state, review_cmd(state.request_id))
    end

    test "review proceeds when sanctions_screening is clean" do
      state = pending_request(%{sanctions_screening: "clean"})

      assert %Nexus.Marketing.Events.AccessRequestReviewed{} =
               AccessRequest.execute(state, review_cmd(state.request_id))
    end
  end
end
