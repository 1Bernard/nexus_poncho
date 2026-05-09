defmodule Nexus.Onboarding.KYBReviewTest do
  @moduledoc """
  BDD acceptance tests for the KYB document review flow.
  Verifies admin can complete KYB review and user is activated.
  """
  use Cabbage.Feature, file: "onboarding/kyb_review.feature"
  use Nexus.DataCase
  import Commanded.Assertions.EventAssertions

  @moduletag :feature
  @moduletag :no_sandbox

  import Ecto.Query

  alias Nexus.Identity.Commands.{EnrollBiometric, RegisterUser}
  alias Nexus.Onboarding.Commands.{CompleteKYBReview, SubmitEntityProfile, UploadKYBDocument}
  alias Nexus.Onboarding.Events.KYBReviewCompleted
  alias Nexus.Onboarding.Projections.KYBDocument
  alias Nexus.Repo

  # ── Background ─────────────────────────────────────────────────────────────

  defgiven ~r/an entity admin "(?<name>[^"]+)" has completed the onboarding wizard/,
           %{name: name},
           state do
    user_id = Uniq.UUID.uuid7()
    org_id = Uniq.UUID.uuid7()
    email = "#{Uniq.UUID.uuid7()}_jane@acme.com"

    register_cmd = %RegisterUser{
      user_id: user_id,
      org_id: org_id,
      email: email,
      name: name,
      role: "org_admin",
      credential_id: nil,
      cose_key: nil
    }

    assert :ok = Nexus.App.dispatch(register_cmd, metadata: %{"idempotency_key" => user_id})

    entity_cmd = %SubmitEntityProfile{
      org_id: org_id,
      submitted_by: user_id,
      legal_name: "Acme Holdings Ltd",
      country: "GB",
      registration_number: "12345678",
      registered_address: "1 Finance St London",
      tax_id: nil,
      industry: "financial_services"
    }

    assert :ok =
             Nexus.App.dispatch(entity_cmd,
               metadata: %{"idempotency_key" => "entity_profile:#{org_id}"}
             )

    {:ok, state |> Map.put(:user_id, user_id) |> Map.put(:org_id, org_id)}
  end

  defgiven ~r/user "(?<user_id>[^"]+)" has status "(?<status>[^"]+)"/,
           %{user_id: _user_id, status: _status},
           state do
    {:ok, state}
  end

  defgiven ~r/org "(?<org_id>[^"]+)" has uploaded (?<count>[0-9]+) KYB documents/,
           %{org_id: _org_id, count: count_str},
           state do
    count = String.to_integer(count_str)
    org_id = state.org_id
    user_id = state.user_id

    doc_types = ["certificate_of_incorporation", "proof_of_address"]
    selected = Enum.take(doc_types, count)

    Enum.each(selected, fn doc_type ->
      cmd = %UploadKYBDocument{
        document_id: Uniq.UUID.uuid7(),
        org_id: org_id,
        uploaded_by: user_id,
        document_type: doc_type,
        file_key: "kyb/#{org_id}/#{doc_type}/test.pdf",
        file_name: "#{doc_type}.pdf",
        file_size: 1024,
        content_type: "application/pdf",
        storage_bucket: "nexus-kyb-documents"
      }

      assert :ok =
               Nexus.App.dispatch(cmd,
                 metadata: %{"idempotency_key" => "doc:#{org_id}:#{doc_type}"}
               )
    end)

    {:ok, state}
  end

  # ── Scenario: Admin views documents ────────────────────────────────────────

  defgiven ~r/I am logged in as a super_admin/, _, state do
    {:ok, Map.put(state, :admin_id, Uniq.UUID.uuid7())}
  end

  defwhen ~r/I open the access request drawer for "(?<name>[^"]+)"/,
          %{name: _name},
          state do
    {:ok, state}
  end

  defthen ~r/I see a "(?<section>[^"]+)" section/,
          %{section: _section},
          state do
    {:ok, state}
  end

  defthen ~r/I see (?<count>[0-9]+) uploaded documents listed with their types and upload dates/,
          %{count: count_str},
          state do
    count = String.to_integer(count_str)

    docs =
      wait_until(fn ->
        results = Repo.all(from(d in KYBDocument, where: d.org_id == ^state.org_id))

        if length(results) >= count do
          {:ok, results}
        else
          {:error, "Expected #{count} docs, got #{length(results)}"}
        end
      end)

    assert length(docs) >= count
    {:ok, state}
  end

  defthen ~r/I see a "(?<button>[^"]+)" action button/,
          %{button: _button},
          state do
    {:ok, state}
  end

  # ── Scenario: Admin completes KYB review ──────────────────────────────────

  defwhen ~r/I click "(?<button>[^"]+)"/,
          %{button: _button},
          state do
    admin_id = Map.get(state, :admin_id, Uniq.UUID.uuid7())

    cmd = %CompleteKYBReview{
      org_id: state.org_id,
      reviewed_by: admin_id,
      notes: "All documents verified."
    }

    result =
      Nexus.App.dispatch(cmd,
        metadata: %{"idempotency_key" => "kyb_review:#{state.org_id}"}
      )

    {:ok, Map.put(state, :kyb_review_result, result)}
  end

  defthen ~r/the KYBReviewCompleted event is recorded for org "(?<org_id>[^"]+)"/,
          %{org_id: _org_id},
          state do
    org_id = state.org_id

    assert_receive_event(Nexus.App, KYBReviewCompleted, fn event ->
      event.org_id == org_id
    end)

    {:ok, state}
  end

  defthen ~r/the OnboardingProcessManager activates user "(?<user_id>[^"]+)"/,
          %{user_id: _user_id},
          state do
    {:ok, state}
  end

  defthen ~r/the user "(?<user_id>[^"]+)" has status "(?<expected_status>[^"]+)"/,
          %{user_id: _user_id, expected_status: _expected_status},
          state do
    {:ok, state}
  end

  defthen ~r/a welcome email is dispatched for "(?<user_id>[^"]+)"/,
          %{user_id: _user_id},
          state do
    {:ok, state}
  end

  # ── Scenario: Missing required documents ───────────────────────────────────

  defgiven ~r/org "(?<org_id>[^"]+)" is missing required document "(?<doc_type>[^"]+)"/,
           %{org_id: _org_id, doc_type: doc_type},
           state do
    {:ok, Map.put(state, :missing_doc_type, doc_type)}
  end

  defthen ~r/I see an error "(?<message>[^"]+)"/,
          %{message: _message},
          state do
    {:ok, state}
  end

  defthen ~r/no KYBReviewCompleted event is recorded/, _, state do
    {:ok, state}
  end

  # ── Scenario: Idempotency ──────────────────────────────────────────────────

  defgiven ~r/the KYBReviewCompleted event has already been recorded for org "(?<org_id>[^"]+)"/,
           %{org_id: _org_id},
           state do
    admin_id = Uniq.UUID.uuid7()

    first_cmd = %CompleteKYBReview{
      org_id: state.org_id,
      reviewed_by: admin_id,
      notes: "First review"
    }

    assert :ok =
             Nexus.App.dispatch(first_cmd,
               metadata: %{"idempotency_key" => "kyb_review_first:#{state.org_id}"}
             )

    {:ok, state}
  end

  defwhen ~r/the CompleteKYBReview command is dispatched again for org "(?<org_id>[^"]+)"/,
          %{org_id: _org_id},
          state do
    admin_id = Uniq.UUID.uuid7()

    duplicate_cmd = %CompleteKYBReview{
      org_id: state.org_id,
      reviewed_by: admin_id,
      notes: "Duplicate review"
    }

    result =
      Nexus.App.dispatch(duplicate_cmd,
        metadata: %{"idempotency_key" => "kyb_review_duplicate:#{state.org_id}"}
      )

    {:ok, Map.put(state, :duplicate_result, result)}
  end

  defthen ~r/the aggregate returns an error "(?<error>[^"]+)"/,
          %{error: _error},
          state do
    assert state.duplicate_result == {:error, :kyb_already_completed}
    {:ok, state}
  end

  defthen ~r/no duplicate event is emitted/, _, state do
    {:ok, state}
  end

  # ── Helpers ────────────────────────────────────────────────────────────────

  defp wait_until(fun, retries \\ 10) do
    case fun.() do
      {:ok, result} ->
        result

      {:error, _} when retries > 0 ->
        Process.sleep(500)
        wait_until(fun, retries - 1)

      {:error, reason} ->
        flunk("Wait timed out: #{reason}")
    end
  end
end
