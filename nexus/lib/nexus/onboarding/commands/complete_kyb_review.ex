defmodule Nexus.Onboarding.Commands.CompleteKYBReview do
  use TypedStruct

  typedstruct enforce: true do
    field(:org_id, String.t())
    field(:reviewed_by, String.t())
    field(:notes, String.t(), enforce: false)
  end
end
