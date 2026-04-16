defmodule NexusTest do
  use ExUnit.Case
  doctest Nexus

  alias Nexus.Accounting.Commands.OpenAccount

  test "dispatching an invalid command returns an error" do
    invalid_command = %OpenAccount{account_id: nil, name: "Test", org_id: "org-1"}
    assert Nexus.dispatch(invalid_command) == {:error, :invalid_aggregate_identity}
  end
end
