defmodule Nexus.Marketing.Commands.SubmitAccessRequest do
  @moduledoc "Command to submit a new institutional access request."
  use TypedStruct

  typedstruct enforce: true do
    field(:request_id, String.t())
    field(:email, String.t())
    field(:name, String.t())
    field(:organization, String.t())
    field(:job_title, String.t())
    field(:treasury_volume, String.t())
    field(:subsidiaries, String.t())
    field(:message, String.t(), enforce: false)
  end
end
