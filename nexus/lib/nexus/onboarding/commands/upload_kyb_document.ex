defmodule Nexus.Onboarding.Commands.UploadKYBDocument do
  use TypedStruct

  typedstruct enforce: true do
    field(:document_id, String.t())
    field(:org_id, String.t())
    field(:uploaded_by, String.t())
    field(:document_type, String.t())
    field(:file_key, String.t())
    field(:file_name, String.t())
    field(:file_size, integer(), enforce: false)
    field(:content_type, String.t(), enforce: false)
    field(:storage_bucket, String.t())
  end
end
