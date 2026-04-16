defmodule Nexus.Treasury.Commands.CreditVault do
  @moduledoc """
  Command to credit a Vault (inflow).
  Follows Standard Chapter 3: Commands & Domain Integrity.
  """
  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:vault_id, String.t(), enforce: true)
    field(:org_id, String.t(), enforce: true)
    field(:amount, Decimal.t(), enforce: true)
    field(:currency, String.t(), enforce: true)
    field(:transfer_id, String.t())
    field(:credited_at, DateTime.t(), enforce: true)
  end
end
