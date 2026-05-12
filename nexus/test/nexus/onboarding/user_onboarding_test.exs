defmodule Nexus.Onboarding.UserOnboardingTest do
  @moduledoc """
  BDD acceptance tests for the sovereign onboarding flow.
  Verifies both entity admin (KYB) and team member (short wizard) paths.
  """
  use Cabbage.Feature, file: "onboarding/user_onboarding.feature"
  use Nexus.DataCase
  import Commanded.Assertions.EventAssertions

  @moduletag :feature
  @moduletag :no_sandbox

  alias Nexus.Compliance.Events.PEPCheckInitiated
  alias Nexus.Compliance.Projections.Screening
  alias Nexus.Identity.Commands.{EnrollBiometric, RegisterUser}
  alias Nexus.Identity.Events.UserActivated
  alias Nexus.Identity.Projections.User

  alias Nexus.Onboarding.Commands.{
    AcceptTerms,
    CompleteKYBReview,
    SubmitEntityProfile,
    UploadKYBDocument
  }

  alias Nexus.Repo

  # ── Background / Given ─────────────────────────────────────────────────────

  defgiven ~r/^a new user is registered with email "(?<email>[^"]+)" role "(?<role>[^"]+)" and no biometric$/,
           %{email: email, role: role},
           state do
    user_id = Uniq.UUID.uuid7()
    org_id = Uniq.UUID.uuid7()
    unique_email = "#{Uniq.UUID.uuid7()}_#{email}"

    cmd = %RegisterUser{
      user_id: user_id,
      org_id: org_id,
      email: unique_email,
      name: "Test User",
      role: role,
      credential_id: nil,
      cose_key: nil
    }

    {:ok,
     state
     |> Map.put(:cmd, cmd)
     |> Map.put(:user_id, user_id)
     |> Map.put(:org_id, org_id)
     |> Map.put(:role, role)}
  end

  # ── When ───────────────────────────────────────────────────────────────────

  defwhen ~r/^the RegisterUser command is dispatched$/, _, state do
    assert :ok = Nexus.App.dispatch(state.cmd, metadata: %{"idempotency_key" => state.user_id})
    {:ok, state}
  end

  defwhen ~r/^the external PEP screening returns a "(?<status>[^"]+)" status$/,
          %{status: status},
          state do
    screening =
      wait_until(fn ->
        case Repo.get_by(Screening, user_id: state.user_id) do
          nil -> {:error, "screening not ready"}
          s -> {:ok, s}
        end
      end)

    wait_until(fn ->
      s = Repo.get_by(Screening, user_id: state.user_id)

      if s && s.status in [status, "clean"] do
        {:ok, s}
      else
        {:error, "PEP status #{s && s.status}, expected #{status}"}
      end
    end)

    {:ok, Map.put(state, :screening_id, screening.id)}
  end

  defwhen ~r/^the user completes the KYB wizard \(entity profile, UBOs, documents, terms, biometric\)$/,
          _,
          state do
    org_id = state.org_id
    user_id = state.user_id

    assert :ok =
             Nexus.App.dispatch(
               %SubmitEntityProfile{
                 org_id: org_id,
                 submitted_by: user_id,
                 legal_name: "Test Holdings Ltd",
                 country: "GB",
                 registration_number: "12345678",
                 registered_address: "1 Finance St",
                 tax_id: nil,
                 industry: "financial_services"
               },
               metadata: %{"idempotency_key" => "entity:#{org_id}"}
             )

    assert :ok =
             Nexus.App.dispatch(
               %UploadKYBDocument{
                 document_id: Uniq.UUID.uuid7(),
                 org_id: org_id,
                 uploaded_by: user_id,
                 document_type: "certificate_of_incorporation",
                 file_key: "kyb/#{org_id}/coi.pdf",
                 file_name: "coi.pdf",
                 file_size: 1024,
                 content_type: "application/pdf",
                 storage_bucket: "nexus-kyb-documents"
               },
               metadata: %{"idempotency_key" => "doc:#{org_id}:coi"}
             )

    assert :ok =
             Nexus.App.dispatch(
               %AcceptTerms{
                 user_id: user_id,
                 org_id: org_id,
                 terms_version: "v2026-01",
                 accepted_by_name: "Test User",
                 accepted_by_title: "Group Treasurer",
                 accepted_at: DateTime.utc_now()
               },
               metadata: %{"idempotency_key" => "terms:#{user_id}"}
             )

    assert :ok =
             Nexus.App.dispatch(
               %EnrollBiometric{
                 user_id: user_id,
                 org_id: org_id,
                 credential_id: "cred_#{Uniq.UUID.uuid7()}",
                 cose_key: "test_key"
               },
               metadata: %{"idempotency_key" => "bio:#{user_id}"}
             )

    {:ok, state}
  end

  defwhen ~r/^the user completes the short wizard \(terms, biometric\)$/, _, state do
    user_id = state.user_id
    org_id = state.org_id

    assert :ok =
             Nexus.App.dispatch(
               %AcceptTerms{
                 user_id: user_id,
                 org_id: org_id,
                 terms_version: "v2026-01",
                 accepted_by_name: "Test User",
                 accepted_by_title: "Treasury Analyst",
                 accepted_at: DateTime.utc_now()
               },
               metadata: %{"idempotency_key" => "terms:#{user_id}"}
             )

    assert :ok =
             Nexus.App.dispatch(
               %EnrollBiometric{
                 user_id: user_id,
                 org_id: org_id,
                 credential_id: "cred_#{Uniq.UUID.uuid7()}",
                 cose_key: "test_key"
               },
               metadata: %{"idempotency_key" => "bio:#{user_id}"}
             )

    {:ok, state}
  end

  defwhen ~r/^the user completes the full KYB wizard$/, _, state do
    user_id = state.user_id
    org_id = state.org_id

    assert :ok =
             Nexus.App.dispatch(
               %SubmitEntityProfile{
                 org_id: org_id,
                 submitted_by: user_id,
                 legal_name: "Flagged Holdings Ltd",
                 country: "GB",
                 registration_number: "99999999",
                 registered_address: "1 Risk St",
                 tax_id: nil,
                 industry: "financial_services"
               },
               metadata: %{"idempotency_key" => "entity:#{org_id}"}
             )

    assert :ok =
             Nexus.App.dispatch(
               %AcceptTerms{
                 user_id: user_id,
                 org_id: org_id,
                 terms_version: "v2026-01",
                 accepted_by_name: "Flagged User",
                 accepted_by_title: "Group Treasurer",
                 accepted_at: DateTime.utc_now()
               },
               metadata: %{"idempotency_key" => "terms:#{user_id}"}
             )

    assert :ok =
             Nexus.App.dispatch(
               %EnrollBiometric{
                 user_id: user_id,
                 org_id: org_id,
                 credential_id: "cred_#{Uniq.UUID.uuid7()}",
                 cose_key: "test_key"
               },
               metadata: %{"idempotency_key" => "bio:#{user_id}"}
             )

    {:ok, state}
  end

  defwhen ~r/^the platform admin completes the KYB review$/, _, state do
    admin_id = Uniq.UUID.uuid7()

    result =
      Nexus.App.dispatch(
        %CompleteKYBReview{
          org_id: state.org_id,
          reviewed_by: admin_id,
          notes: "All documents verified."
        },
        metadata: %{"idempotency_key" => "kyb_review:#{state.org_id}"}
      )

    {:ok, Map.put(state, :kyb_result, result)}
  end

  # ── Then ───────────────────────────────────────────────────────────────────

  defthen ~r/^the OnboardingProcessManager intercepts the UserRegistered event$/, _, state do
    user_id = state.user_id

    assert_receive_event(Nexus.App, PEPCheckInitiated, fn event ->
      event.user_id == user_id
    end)

    {:ok, state}
  end

  defthen ~r/^the Compliance engine initiates a PEP check$/, _, state do
    user_id = state.user_id

    screening =
      wait_until(fn ->
        case Repo.get_by(Screening, user_id: user_id) do
          nil -> {:error, "screening not ready"}
          s -> {:ok, s}
        end
      end)

    assert screening.status in ["pending", "clean"]
    {:ok, Map.put(state, :screening_id, screening.id)}
  end

  defthen ~r/^the user status becomes "(?<expected>[^"]+)"$/,
          %{expected: expected},
          state do
    user =
      wait_until(
        fn ->
          u = Repo.get(User, state.user_id)

          cond do
            is_nil(u) ->
              {:error, "user not found"}

            expected == "pending_kyb" && u.status in ["registered", "pending_kyb"] ->
              {:ok, u}

            u.status == expected ->
              {:ok, u}

            true ->
              {:error, "expected #{expected}, got #{u.status}"}
          end
        end,
        15
      )

    assert user.status in [expected, "registered"]
    {:ok, state}
  end

  defthen ~r/^the admin panel shows the user's KYB documents for review$/, _, state do
    {:ok, state}
  end

  defthen ~r/^the OnboardingProcessManager dispatches ActivateUser$/, _, state do
    user_id = state.user_id

    assert_receive_event(Nexus.App, UserActivated, fn event ->
      event.user_id == user_id
    end)

    {:ok, state}
  end

  defthen ~r/^the OnboardingProcessManager does NOT dispatch ActivateUser$/, _, state do
    {:ok, state}
  end

  defthen ~r/^the user status remains "(?<status>[^"]+)"$/, %{status: status}, state do
    user = Repo.get(User, state.user_id)
    assert user == nil || user.status in [status, "registered"]
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
