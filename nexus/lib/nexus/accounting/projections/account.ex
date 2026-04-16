defmodule Nexus.Accounting.Projections.Account do
  @moduledoc """
  Read-model schema for a ledger account.
  """
  use Nexus.Schema

  schema "accounting_accounts" do
    field(:org_id, :binary_id)
    field(:name, :string)
    field(:balance, :decimal, default: 0)

    timestamps()
  end

  def changeset(account, attrs) do
    account
    |> cast(attrs, [:id, :org_id, :name, :balance])
    |> validate_required([:id, :org_id, :name])
  end
end
