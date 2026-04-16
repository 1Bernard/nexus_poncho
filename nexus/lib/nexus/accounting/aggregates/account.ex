defmodule Nexus.Accounting.Aggregates.Account do
  @moduledoc """
  Account aggregate for ledger operations.
  """
  @derive Jason.Encoder
  defstruct [:org_id, :account_id, :name, :opened_at, balance: Decimal.new(0)]

  alias Nexus.Accounting.Commands.OpenAccount
  alias Nexus.Accounting.Events.AccountOpened
  alias Nexus.Schema

  # ==================== COMMANDS ====================

  def execute(%__MODULE__{account_id: nil}, %OpenAccount{} = command) do
    if command.account_id in [nil, ""] do
      {:error, :account_id_required}
    else
      %AccountOpened{
        org_id: command.org_id,
        account_id: command.account_id,
        name: command.name,
        opened_at: Schema.utc_now()
      }
    end
  end

  def execute(%__MODULE__{}, %OpenAccount{}) do
    {:error, :account_already_opened}
  end

  # ==================== EVENTS ====================

  def apply(%__MODULE__{} = state, %AccountOpened{} = event) do
    %__MODULE__{
      state
      | org_id: event.org_id,
        account_id: event.account_id,
        name: event.name,
        opened_at: event.opened_at,
        balance: Decimal.new(0)
    }
  end
end
