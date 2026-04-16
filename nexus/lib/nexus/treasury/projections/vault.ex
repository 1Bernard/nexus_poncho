defmodule Nexus.Treasury.Projections.Vault do
  @moduledoc """
  Read model for a Vault.
  Used by the Web layer for dashboard display.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id

  schema "treasury_vaults" do
    field(:org_id, :binary_id)
    field(:name, :string)
    field(:bank_name, :string)
    field(:account_number, :string)
    field(:iban, :string)
    field(:currency, :string)
    field(:balance, :decimal, default: 0)
    field(:provider, :string)
    field(:status, :string)
    field(:daily_withdrawal_limit, :decimal)
    field(:requires_multi_sig, :boolean, default: false)

    timestamps()
  end

  def changeset(vault, attrs) do
    vault
    |> cast(attrs, [
      :id,
      :org_id,
      :name,
      :bank_name,
      :account_number,
      :iban,
      :currency,
      :balance,
      :provider,
      :status,
      :daily_withdrawal_limit,
      :requires_multi_sig
    ])
    |> validate_required([:id, :org_id, :name, :currency, :balance, :status])
  end
end
