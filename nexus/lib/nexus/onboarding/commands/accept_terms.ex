defmodule Nexus.Onboarding.Commands.AcceptTerms do
  use TypedStruct

  typedstruct enforce: true do
    field(:user_id, String.t())
    field(:org_id, String.t())
    field(:terms_version, String.t())
    field(:accepted_by_name, String.t())
    field(:accepted_by_title, String.t())
    field(:accepted_at, DateTime.t())
  end
end
