defmodule Nexus.Treasury.Events.VaultRegistered do
  @moduledoc """
  Event emitted when a new vault is registered.
  Follows Standard: Audit trail precision.
  """
  use TypedStruct

  @derive Jason.Encoder

  typedstruct enforce: true do
    field(:vault_id, String.t(), doc: "A unique vault identifier")
    field(:org_id, String.t(), doc: "Organization identifier")
    field(:name, String.t(), doc: "Vault name")
    field(:currency, String.t(), doc: "Vault currency (ISO-4217 code)")
    field(:bank_name, String.t(), doc: "Name of the partner bank")
    field(:account_number, String.t(), doc: "Internal account number")
    field(:iban, String.t(), doc: "International Bank Account Number")
    field(:provider, String.t(), doc: "Partner provider")
    field(:daily_withdrawal_limit, Integer.t(), doc: "Max daily output limit")
    field(:requires_multi_sig, Boolean.t(), doc: "Multi-signature requirement flag")
  end
end
