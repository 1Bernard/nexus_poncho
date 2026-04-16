defmodule Nexus.Treasury.Events.VaultCredited do
  @moduledoc """
  Event emitted when a vault is credited.
  Follows Standard: Audit trail precision.
  """
  use TypedStruct

  @derive Jason.Encoder

  typedstruct enforce: true do
    field(:vault_id, String.t(), doc: "A unique vault identifier")
    field(:org_id, String.t(), doc: "A unique organization identifier")
    field(:amount, Decimal.t(), doc: "Amount to credit")
    field(:transfer_id, String.t(), doc: "Unique transfer identifier")
  end
end
