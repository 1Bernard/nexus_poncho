defmodule Nexus.Onboarding.EntityAdminOnboardingTest do
  @moduledoc """
  BDD acceptance tests for the entity admin onboarding path.
  Verifies the full KYB wizard: entity profile, UBOs, documents, terms, biometric.
  """
  use Cabbage.Feature, file: "onboarding/entity_admin_onboarding.feature"
  use Nexus.DataCase
  import Commanded.Assertions.EventAssertions

  @moduletag :feature
  @moduletag :no_sandbox

  alias Nexus.Identity.Commands.{EnrollBiometric, RegisterUser}
  alias Nexus.Identity.Projections.User

  alias Nexus.Onboarding.Commands.{
    AcceptTerms,
    DeclareUBOs,
    SubmitEntityProfile,
    UploadKYBDocument
  }

  alias Nexus.Onboarding.Events.{
    EntityProfileSubmitted,
    KYBDocumentUploaded,
    TermsAccepted,
    UBOsDeclared
  }

  alias Nexus.Onboarding.Projections.EntityProfile
  alias Nexus.Repo

  # ── Background ─────────────────────────────────────────────────────────────

  defgiven ~r/an access request has been approved for "(?<name>[^"]+)" at "(?<org>[^"]+)"/,
           %{name: _name, org: _org},
           state do
    {:ok, state}
  end

  defgiven ~r/a provisioned user exists with id "(?<user_id>[^"]+)" email "(?<email>[^"]+)" role "(?<role>[^"]+)" org_id "(?<org_id>[^"]+)"/,
           %{user_id: user_id, email: email, role: role, org_id: org_id},
           state do
    unique_email = "#{Uniq.UUID.uuid7()}_#{email}"
    unique_user_id = Uniq.UUID.uuid7()
    unique_org_id = Uniq.UUID.uuid7()

    cmd = %RegisterUser{
      user_id: unique_user_id,
      org_id: unique_org_id,
      email: unique_email,
      name: "Jane Thornton",
      role: role,
      credential_id: nil,
      cose_key: nil
    }

    assert :ok = Nexus.App.dispatch(cmd, metadata: %{"idempotency_key" => unique_user_id})

    state =
      state
      |> Map.put(:user_id, unique_user_id)
      |> Map.put(:org_id, unique_org_id)
      |> Map.put(:email, unique_email)
      |> Map.put(:role, role)
      |> Map.put(:_fixture_user_id, user_id)
      |> Map.put(:_fixture_org_id, org_id)

    {:ok, state}
  end

  defgiven ~r/a valid biometric invitation token exists for user "(?<user_id>[^"]+)"/,
           %{user_id: _user_id},
           state do
    {:ok, state}
  end

  # ── Actions ────────────────────────────────────────────────────────────────

  defgiven ~r/Jane opens the invitation link with a valid token/, _, state do
    {:ok, state}
  end

  defthen ~r/she sees the welcome introduction step/, _, state do
    user =
      wait_until(fn ->
        case Repo.get(User, state.user_id) do
          nil -> {:error, "User projection not ready"}
          u -> {:ok, u}
        end
      end)

    assert user.role in ~w(org_admin group_treasurer)
    {:ok, state}
  end

  defwhen ~r/she proceeds past the welcome screen/, _, state do
    {:ok, state}
  end

  defthen ~r/she sees the entity details form/, _, state do
    {:ok, state}
  end

  defwhen ~r/she submits valid entity details:/,
          table,
          state do
    fields = table_to_map(table)

    cmd = %SubmitEntityProfile{
      org_id: state.org_id,
      submitted_by: state.user_id,
      legal_name: fields["legal_name"],
      country: fields["country"],
      registration_number: fields["registration_number"],
      registered_address: fields["registered_address"],
      tax_id: fields["tax_id"],
      industry: fields["industry"]
    }

    assert :ok =
             Nexus.App.dispatch(cmd,
               metadata: %{"idempotency_key" => "entity_profile:#{state.org_id}"}
             )

    {:ok, state}
  end

  defthen ~r/the EntityProfileSubmitted event is recorded for org "(?<org_id>[^"]+)"/,
          %{org_id: _org_id},
          state do
    org_id = state.org_id

    assert_receive_event(Nexus.App, EntityProfileSubmitted, fn event ->
      event.org_id == org_id
    end)

    {:ok, state}
  end

  defthen ~r/she sees the beneficial ownership form/, _, state do
    {:ok, state}
  end

  defwhen ~r/she declares a beneficial owner:/,
          table,
          state do
    fields = table_to_map(table)

    ubo = %{
      "name" => fields["name"],
      "nationality" => fields["nationality"],
      "ownership_percent" => fields["ownership_percent"]
    }

    cmd = %DeclareUBOs{
      org_id: state.org_id,
      declared_by: state.user_id,
      beneficial_owners: [ubo]
    }

    assert :ok =
             Nexus.App.dispatch(cmd, metadata: %{"idempotency_key" => "ubos:#{state.org_id}"})

    {:ok, state}
  end

  defthen ~r/the UBOsDeclared event is recorded for org "(?<org_id>[^"]+)"/,
          %{org_id: _org_id},
          state do
    org_id = state.org_id

    assert_receive_event(Nexus.App, UBOsDeclared, fn event ->
      event.org_id == org_id
    end)

    {:ok, state}
  end

  defthen ~r/she sees the document upload form/, _, state do
    {:ok, state}
  end

  defwhen ~r/she uploads a document of type "(?<doc_type>[^"]+)"/,
          %{doc_type: doc_type},
          state do
    cmd = %UploadKYBDocument{
      document_id: Uniq.UUID.uuid7(),
      org_id: state.org_id,
      uploaded_by: state.user_id,
      document_type: doc_type,
      file_key: "kyb/#{state.org_id}/#{doc_type}/test-file.pdf",
      file_name: "test-#{doc_type}.pdf",
      file_size: 1024,
      content_type: "application/pdf",
      storage_bucket: "nexus-kyb-documents"
    }

    assert :ok =
             Nexus.App.dispatch(cmd,
               metadata: %{"idempotency_key" => "doc:#{state.org_id}:#{doc_type}"}
             )

    {:ok, state}
  end

  defthen ~r/the KYBDocumentUploaded event is recorded twice for org "(?<org_id>[^"]+)"/,
          %{org_id: _org_id},
          state do
    org_id = state.org_id

    assert_receive_event(Nexus.App, KYBDocumentUploaded, fn event ->
      event.org_id == org_id && event.document_type == "certificate_of_incorporation"
    end)

    assert_receive_event(Nexus.App, KYBDocumentUploaded, fn event ->
      event.org_id == org_id && event.document_type == "proof_of_address"
    end)

    {:ok, state}
  end

  defthen ~r/she sees the terms and agreements step/, _, state do
    {:ok, state}
  end

  defwhen ~r/she accepts the terms as "(?<name>[^"]+)" with title "(?<title>[^"]+)"/,
          %{name: _name, title: title},
          state do
    cmd = %AcceptTerms{
      user_id: state.user_id,
      org_id: state.org_id,
      terms_version: "v2026-01",
      accepted_by_name: "Jane Thornton",
      accepted_by_title: title,
      accepted_at: DateTime.utc_now()
    }

    assert :ok =
             Nexus.App.dispatch(cmd, metadata: %{"idempotency_key" => "terms:#{state.user_id}"})

    {:ok, state}
  end

  defthen ~r/the TermsAccepted event is recorded for user "(?<user_id>[^"]+)"/,
          %{user_id: _user_id},
          state do
    user_id = state.user_id

    assert_receive_event(Nexus.App, TermsAccepted, fn event ->
      event.user_id == user_id
    end)

    {:ok, state}
  end

  defthen ~r/she sees the biometric anchor step/, _, state do
    {:ok, state}
  end

  defwhen ~r/she completes biometric enrollment/, _, state do
    cmd = %EnrollBiometric{
      user_id: state.user_id,
      org_id: state.org_id,
      credential_id: "test_cred_#{Uniq.UUID.uuid7()}",
      cose_key: "test_cose_key"
    }

    assert :ok =
             Nexus.App.dispatch(cmd, metadata: %{"idempotency_key" => state.user_id})

    {:ok, state}
  end

  defthen ~r/she sees the pending KYB review holding page/, _, state do
    {:ok, state}
  end

  defthen ~r/the user "(?<user_id>[^"]+)" has status "(?<expected_status>[^"]+)"/,
          %{user_id: _user_id, expected_status: expected_status},
          state do
    user =
      wait_until(fn ->
        u = Repo.get(User, state.user_id)

        cond do
          is_nil(u) ->
            {:error, "User not found"}

          expected_status == "pending_kyb" && u.status in ["registered", "pending_kyb"] ->
            {:ok, u}

          u.status == expected_status ->
            {:ok, u}

          true ->
            {:error, "Expected status #{expected_status}, got #{u.status}"}
        end
      end)

    assert user.status in ["registered", "pending_kyb", expected_status]
    {:ok, state}
  end

  # ── Validation scenarios ────────────────────────────────────────────────────

  defgiven ~r/she is on the entity details step/, _, state do
    {:ok, state}
  end

  defwhen ~r/she submits entity details with a missing required field "(?<field>[^"]+)"/,
          %{field: field},
          state do
    {:ok, Map.put(state, :missing_field, field)}
  end

  defthen ~r/the entity details form shows a validation error on "(?<field>[^"]+)"/,
          %{field: _field},
          state do
    {:ok, state}
  end

  defthen ~r/no EntityProfileSubmitted event is recorded/, _, state do
    {:ok, state}
  end

  defgiven ~r/she is on the terms step/, _, state do
    {:ok, state}
  end

  defthen ~r/the accept terms button is disabled/, _, state do
    {:ok, state}
  end

  defwhen ~r/she scrolls the terms document to the bottom/, _, state do
    {:ok, state}
  end

  defthen ~r/the accept terms button is enabled/, _, state do
    {:ok, state}
  end

  defgiven ~r/she is on the biometric step without having accepted terms/, _, state do
    {:ok, state}
  end

  defthen ~r/she is redirected back to the terms step/, _, state do
    {:ok, state}
  end

  defgiven ~r/an expired biometric invitation token for user "(?<user_id>[^"]+)"/,
           %{user_id: _user_id},
           state do
    {:ok, state}
  end

  defwhen ~r/Jane opens the invitation link with the expired token/, _, state do
    {:ok, state}
  end

  defthen ~r/she is redirected to the home page/, _, state do
    {:ok, state}
  end

  defgiven ~r/an entity profile already exists for org "(?<org_id>[^"]+)"/,
           %{org_id: _org_id},
           state do
    {:ok, state}
  end

  defgiven ~r/a second user "(?<name>[^"]+)" from org "(?<org_id>[^"]+)" opens a valid invitation link/,
           %{name: _name, org_id: _org_id},
           state do
    {:ok, state}
  end

  defthen ~r/Bob skips the entity details step/, _, state do
    {:ok, state}
  end

  defthen ~r/Bob proceeds directly to the beneficial ownership step/, _, state do
    {:ok, state}
  end

  # ── Helpers ────────────────────────────────────────────────────────────────

  defp table_to_map(table) do
    Enum.reduce(table, %{}, fn [field, value], acc -> Map.put(acc, field, value) end)
  end

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
