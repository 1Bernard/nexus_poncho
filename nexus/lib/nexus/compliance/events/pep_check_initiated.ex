defmodule Nexus.Compliance.Events.PEPCheckInitiated do
  @moduledoc """
  Event emitted when a PEP screening begins.
  """
  use TypedStruct

  @derive Jason.Encoder

  typedstruct enforce: true do
    field(:screening_id, String.t())
    field(:user_id, String.t())
    field(:org_id, String.t())
    field(:name, String.t())
    field(:credential_id, String.t())
    field(:cose_key, String.t())
  end
end
