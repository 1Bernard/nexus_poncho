defmodule Nexus.Accounting.Commands.OpenAccount do
  @moduledoc """
  Command to open a new ledger account.
  """
  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:org_id, String.t(), enforce: true)
    field(:account_id, String.t(), enforce: true)
    field(:name, String.t(), enforce: true)
  end
end
