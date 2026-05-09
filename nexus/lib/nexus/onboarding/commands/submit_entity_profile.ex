defmodule Nexus.Onboarding.Commands.SubmitEntityProfile do
  use TypedStruct

  typedstruct enforce: true do
    field(:org_id, String.t())
    field(:submitted_by, String.t())
    field(:legal_name, String.t())
    field(:country, String.t())
    field(:registration_number, String.t())
    field(:registered_address, String.t())
    field(:tax_id, String.t(), enforce: false)
    field(:industry, String.t())
  end
end
