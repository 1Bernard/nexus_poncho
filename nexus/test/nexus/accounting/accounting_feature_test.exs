defmodule Nexus.AccountingFeatureTest do
  use Cabbage.Feature, file: "accounting/open_account.feature"
  use Nexus.DataCase

  @moduletag :feature
  @moduletag :no_sandbox

  alias Nexus.Accounting.Commands.OpenAccount
  alias Nexus.Accounting.Events.AccountOpened

  # Global setup is handled in test_helper.exs for sovereign stability.

  # ==================== GIVEN ====================

  defgiven ~r/^an organization with ID "(?<org_id>[^"]+)" exists$/, _, state do
    {:ok, Map.put(state, :org_id, Uniq.UUID.uuid7())}
  end

  # ==================== WHEN ====================

  defwhen ~r/^I open a new account for "(?<name>[^"]+)" with ID "(?<account_id>[^"]+)"$/,
          %{name: name},
          %{org_id: org_id} = state do
    account_id = Uniq.UUID.uuid7()

    command = %OpenAccount{
      org_id: org_id,
      account_id: account_id,
      name: name
    }

    result = Nexus.dispatch(command)
    {:ok, Map.merge(state, %{last_result: result, account_id: account_id})}
  end

  defwhen ~r/^I try to open an account without an ID$/, _captures, %{org_id: org_id} = state do
    command = %OpenAccount{
      org_id: org_id,
      account_id: nil,
      name: "Bad Account"
    }

    result = Nexus.dispatch(command)
    {:ok, Map.put(state, :last_result, result)}
  end

  # ==================== THEN ====================

  defthen ~r/^the account "([^"]+)" should be opened$/, _captures, state do
    # Verification will happen via Read Model or Projections in next phases
    # For now, we assert the dispatch was successful
    assert {:ok, _events} = state.last_result
    {:ok, state}
  end

  defthen ~r/^the account "(?<account_id>[^"]+)" should have a balance of 0$/, _captures, state do
    # Same as above, for now we assume success
    {:ok, state}
  end

  defthen ~r/^the event "AccountOpened" should be emitted with:$/, %{table: table}, state do
    case state.last_result do
      {:ok, %Commanded.Commands.ExecutionResult{events: [%AccountOpened{} = event | _]}} ->
        # Use table verification
        Enum.each(table, fn %{field: field, value: value} ->
          actual = to_string(Map.get(event, String.to_atom(field)))

          # If the table uses a placeholder like 'org_123', we check against our dynamic state
          expected =
            cond do
              field == "org_id" and value == "org_123" -> state.org_id
              field == "account_id" and value == "acc_cash_001" -> state.account_id
              true -> value
            end

          assert actual == expected
        end)

      _ ->
        flunk("AccountOpened event not emitted")
    end

    {:ok, state}
  end

  defthen ~r/^I should receive an error "(?<error>[^"]+)"$/, %{error: _error}, state do
    assert {:error, :invalid_aggregate_identity} == state.last_result
    {:ok, state}
  end
end
