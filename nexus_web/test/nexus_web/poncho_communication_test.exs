defmodule NexusWeb.PonchoCommunicationTest do
  use NexusWeb.ConnCase, async: true

  @moduledoc """
  Verification test for Poncho-style inter-app communication.
  Ensures the 'Face' (nexus_web) can reliably communicate with the 'Soul' (nexus).
  """

  test "nexus_web can access the Nexus public API" do
    # Verify the Nexus module is available from the dependency
    assert Code.ensure_loaded?(Nexus)

    # Verify we can access the public API functions
    assert function_exported?(Nexus, :dispatch, 1)
    assert function_exported?(Nexus, :query, 1)
  end

  test "nexus_web can reach the Nexus Repo (shared connectivity)" do
    # This verifies that the database configuration is shared and reachable
    assert Nexus.Repo.aggregate(Nexus.Accounting.Projections.Account, :count, :id) >= 0
  end
end
