defmodule Nexus.Onboarding.Events.KYBReviewCompleted do
  @moduledoc false
  use TypedStruct

  @derive Jason.Encoder

  typedstruct enforce: true do
    field(:org_id, String.t())
    field(:user_id, String.t())
    field(:reviewed_by, String.t())
    field(:reviewed_at, DateTime.t())
    field(:notes, String.t(), enforce: false)
  end
end
