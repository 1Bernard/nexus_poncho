defmodule Nexus.Accounting.Events.AccountOpened do
  @moduledoc """
  Event emitted when a new ledger account is successfully opened.
  """
  use TypedStruct

  @derive Jason.Encoder

  @derive Jason.Encoder
  typedstruct do
    field(:org_id, String.t(), enforce: true)
    field(:account_id, String.t(), enforce: true)
    field(:name, String.t(), enforce: true)
    field(:opened_at, DateTime.t(), enforce: true)
  end
end
