defmodule Nexus.Onboarding.Events.UBOsDeclared do
  @moduledoc false
  use TypedStruct

  @derive Jason.Encoder

  typedstruct enforce: true do
    field(:org_id, String.t())
    field(:declared_by, String.t())
    field(:beneficial_owners, list(map()))
  end
end
