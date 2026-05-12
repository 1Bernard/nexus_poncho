defmodule Nexus.Onboarding.Commands.DeclareUBOs do
  @moduledoc false
  use TypedStruct

  typedstruct enforce: true do
    field(:org_id, String.t())
    field(:declared_by, String.t())
    # Each entry: %{name: string, nationality: string, ownership_percent: integer}
    field(:beneficial_owners, list(map()))
  end
end
