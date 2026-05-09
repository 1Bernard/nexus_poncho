defmodule Nexus.Onboarding.Aggregates.EntityKyb do
  @moduledoc """
  Aggregate governing the KYB lifecycle for an organisational entity.
  Identified by org_id. Tracks entity profile, UBOs, document uploads,
  and the admin KYB review gate.

  State machine:
    nil → incomplete → pending_review → complete
  """

  defstruct [
    :org_id,
    :user_id,
    :kyb_status,
    :legal_name,
    :country,
    :registration_number,
    :registered_address,
    :tax_id,
    :industry,
    beneficial_owners: [],
    uploaded_document_types: [],
    document_count: 0
  ]

  alias __MODULE__, as: EntityKyb

  alias Nexus.Onboarding.Commands.{
    CompleteKYBReview,
    DeclareUBOs,
    SubmitEntityProfile,
    UploadKYBDocument
  }

  alias Nexus.Onboarding.Events.{
    EntityProfileSubmitted,
    KYBDocumentUploaded,
    KYBReviewCompleted,
    UBOsDeclared
  }

  @required_document_types ~w(certificate_of_incorporation proof_of_address)

  # ── Command Handlers ──────────────────────────────────────────────────────

  def execute(%EntityKyb{org_id: nil}, %SubmitEntityProfile{} = cmd) do
    %EntityProfileSubmitted{
      org_id: cmd.org_id,
      submitted_by: cmd.submitted_by,
      legal_name: cmd.legal_name,
      country: cmd.country,
      registration_number: cmd.registration_number,
      registered_address: cmd.registered_address,
      tax_id: cmd.tax_id,
      industry: cmd.industry
    }
  end

  def execute(%EntityKyb{kyb_status: status}, %SubmitEntityProfile{}) when status != nil do
    {:error, :entity_profile_already_submitted}
  end

  def execute(%EntityKyb{org_id: org_id}, %DeclareUBOs{} = cmd) when not is_nil(org_id) do
    %UBOsDeclared{
      org_id: cmd.org_id,
      declared_by: cmd.declared_by,
      beneficial_owners: cmd.beneficial_owners
    }
  end

  def execute(%EntityKyb{org_id: nil}, %DeclareUBOs{}) do
    {:error, :entity_profile_not_submitted}
  end

  def execute(%EntityKyb{org_id: org_id}, %UploadKYBDocument{} = cmd) when not is_nil(org_id) do
    %KYBDocumentUploaded{
      document_id: cmd.document_id,
      org_id: cmd.org_id,
      uploaded_by: cmd.uploaded_by,
      document_type: cmd.document_type,
      file_key: cmd.file_key,
      file_name: cmd.file_name,
      file_size: cmd.file_size,
      content_type: cmd.content_type,
      storage_bucket: cmd.storage_bucket
    }
  end

  def execute(%EntityKyb{org_id: nil}, %UploadKYBDocument{}) do
    {:error, :entity_profile_not_submitted}
  end

  def execute(%EntityKyb{kyb_status: "complete"}, %CompleteKYBReview{}) do
    {:error, :kyb_already_completed}
  end

  def execute(%EntityKyb{} = state, %CompleteKYBReview{} = cmd) do
    missing = @required_document_types -- state.uploaded_document_types

    if missing != [] do
      {:error, {:missing_required_documents, missing}}
    else
      %KYBReviewCompleted{
        org_id: cmd.org_id,
        user_id: state.user_id,
        reviewed_by: cmd.reviewed_by,
        reviewed_at: DateTime.utc_now(),
        notes: cmd.notes
      }
    end
  end

  # ── State Transitions ─────────────────────────────────────────────────────

  def apply(%EntityKyb{} = state, %EntityProfileSubmitted{} = event) do
    %EntityKyb{
      state
      | org_id: event.org_id,
        user_id: event.submitted_by,
        legal_name: event.legal_name,
        country: event.country,
        registration_number: event.registration_number,
        registered_address: event.registered_address,
        tax_id: event.tax_id,
        industry: event.industry,
        kyb_status: "incomplete"
    }
  end

  def apply(%EntityKyb{} = state, %UBOsDeclared{} = event) do
    %EntityKyb{state | beneficial_owners: event.beneficial_owners}
  end

  def apply(%EntityKyb{} = state, %KYBDocumentUploaded{} = event) do
    types = [event.document_type | state.uploaded_document_types] |> Enum.uniq()

    %EntityKyb{
      state
      | uploaded_document_types: types,
        document_count: state.document_count + 1,
        kyb_status: "incomplete"
    }
  end

  def apply(%EntityKyb{} = state, %KYBReviewCompleted{}) do
    %EntityKyb{state | kyb_status: "complete"}
  end
end
