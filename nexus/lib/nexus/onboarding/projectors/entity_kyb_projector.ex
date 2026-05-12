defmodule Nexus.Onboarding.Projectors.EntityKybProjector do
  @moduledoc false
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    repo: Nexus.Repo,
    name: "Onboarding.EntityKybProjector"

  import Ecto.Query

  alias Ecto.Multi

  alias Nexus.Onboarding.Events.{
    EntityProfileSubmitted,
    KYBDocumentUploaded,
    KYBReviewCompleted,
    UBOsDeclared
  }

  alias Nexus.Onboarding.Projections.{EntityProfile, KYBDocument}

  require Logger

  project(%EntityProfileSubmitted{} = event, _metadata, fn multi ->
    attrs = %{
      id: Uniq.UUID.uuid7(),
      org_id: event.org_id,
      legal_name: event.legal_name,
      country: event.country,
      registration_number: event.registration_number,
      registered_address: event.registered_address,
      tax_id: event.tax_id,
      industry: event.industry,
      submitted_by: event.submitted_by,
      kyb_status: "incomplete"
    }

    changeset = EntityProfile.changeset(%EntityProfile{}, attrs)

    Multi.insert(multi, :upsert_entity_profile, changeset,
      on_conflict:
        {:replace,
         [
           :legal_name,
           :country,
           :registration_number,
           :registered_address,
           :tax_id,
           :industry,
           :submitted_by,
           :updated_at
         ]},
      conflict_target: :org_id
    )
  end)

  project(%UBOsDeclared{} = event, _metadata, fn multi ->
    query = from(p in EntityProfile, where: p.org_id == ^event.org_id)

    Multi.update_all(multi, :update_ubos, query,
      set: [
        beneficial_owners: event.beneficial_owners,
        updated_at: DateTime.utc_now()
      ]
    )
  end)

  project(%KYBDocumentUploaded{} = event, _metadata, fn multi ->
    attrs = %{
      id: event.document_id,
      org_id: event.org_id,
      document_type: event.document_type,
      file_key: event.file_key,
      file_name: event.file_name,
      file_size: event.file_size,
      content_type: event.content_type,
      uploaded_by: event.uploaded_by,
      storage_bucket: event.storage_bucket
    }

    changeset = KYBDocument.changeset(%KYBDocument{}, attrs)

    Multi.insert(multi, :"insert_doc_#{event.document_id}", changeset,
      on_conflict: :nothing,
      conflict_target: :id
    )
  end)

  project(%KYBReviewCompleted{} = event, _metadata, fn multi ->
    query = from(p in EntityProfile, where: p.org_id == ^event.org_id)

    Multi.update_all(multi, :complete_kyb, query,
      set: [
        kyb_status: "complete",
        reviewed_by: event.reviewed_by,
        reviewed_at: event.reviewed_at,
        updated_at: DateTime.utc_now()
      ]
    )
  end)
end
