defmodule NexusShared.Accounts.Events.AccountOpened do
  @derive [Jason.Encoder]
  defstruct [:account_id, :owner_name, :initial_balance]
end
