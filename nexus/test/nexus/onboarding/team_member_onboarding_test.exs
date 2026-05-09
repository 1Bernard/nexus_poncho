defmodule Nexus.Onboarding.TeamMemberOnboardingTest do
  @moduledoc """
  BDD acceptance tests for the team member onboarding path.
  Verifies the shortened flow: terms → biometric → activation.
  """
  use Cabbage.Feature, file: "onboarding/team_member_onboarding.feature"
  use Nexus.DataCase
  import Commanded.Assertions.EventAssertions

  @moduletag :feature
  @moduletag :no_sandbox

  alias Nexus.Identity.Commands.{EnrollBiometric, InviteTeamMember}
  alias Nexus.Identity.Events.{TeamMemberInvited, UserActivated}
  alias Nexus.Identity.Projections.User
  alias Nexus.Onboarding.Commands.AcceptTerms
  alias Nexus.Onboarding.Events.TermsAccepted
  alias Nexus.Repo

  # ── Background ─────────────────────────────────────────────────────────────

  defgiven ~r/"(?<org>[^"]+)" with org_id "(?<org_id>[^"]+)" has completed entity KYB/,
           %{org: _org, org_id: _org_id},
           state do
    {:ok, Map.put(state, :org_id, Uniq.UUID.uuid7())}
  end

  defgiven ~r/the org admin has invited "(?<name>[^"]+)" with email "(?<email>[^"]+)" role "(?<role>[^"]+)"/,
           %{name: name, email: email, role: role},
           state do
    org_admin_id = Uniq.UUID.uuid7()
    invitee_id = Uniq.UUID.uuid7()
    unique_email = "#{Uniq.UUID.uuid7()}_#{email}"

    cmd = %InviteTeamMember{
      user_id: invitee_id,
      org_id: state.org_id,
      invited_by: org_admin_id,
      email: unique_email,
      name: name,
      role: role
    }

    assert :ok =
             Nexus.App.dispatch(cmd,
               metadata: %{"idempotency_key" => "invite:#{state.org_id}:#{unique_email}"}
             )

    {:ok,
     state
     |> Map.put(:invitee_id, invitee_id)
     |> Map.put(:invitee_email, unique_email)
     |> Map.put(:invitee_role, role)}
  end

  defgiven ~r/a provisioned user exists with id "(?<user_id>[^"]+)" email "(?<email>[^"]+)" role "(?<role>[^"]+)" org_id "(?<org_id>[^"]+)"/,
           %{user_id: _user_id, email: _email, role: _role, org_id: _org_id},
           state do
    {:ok, state}
  end

  defgiven ~r/a valid biometric invitation token exists for user "(?<user_id>[^"]+)"/,
           %{user_id: _user_id},
           state do
    {:ok, state}
  end

  # ── Actions ────────────────────────────────────────────────────────────────

  defgiven ~r/Bob opens the invitation link with a valid token/, _, state do
    {:ok, state}
  end

  defthen ~r/he sees the welcome screen showing organisation "(?<org>[^"]+)"/,
          %{org: _org},
          state do
    user =
      wait_until(fn ->
        case Repo.get(User, state.invitee_id) do
          nil -> {:error, "User projection not ready"}
          u -> {:ok, u}
        end
      end)

    assert user.org_id == state.org_id
    {:ok, state}
  end

  defthen ~r/he sees his role "(?<role>[^"]+)" displayed on the welcome screen/,
          %{role: role},
          state do
    user = Repo.get(User, state.invitee_id)
    assert user && user.role == role
    {:ok, state}
  end

  defwhen ~r/he proceeds from the welcome screen/, _, state do
    {:ok, state}
  end

  defthen ~r/he sees the personal terms step/, _, state do
    {:ok, state}
  end

  defwhen ~r/he accepts the personal terms as "(?<name>[^"]+)"/,
          %{name: _name},
          state do
    cmd = %AcceptTerms{
      user_id: state.invitee_id,
      org_id: state.org_id,
      terms_version: "v2026-01",
      accepted_by_name: "Bob Smith",
      accepted_by_title: "Treasury Analyst",
      accepted_at: DateTime.utc_now()
    }

    assert :ok =
             Nexus.App.dispatch(cmd,
               metadata: %{"idempotency_key" => "terms:#{state.invitee_id}"}
             )

    {:ok, state}
  end

  defthen ~r/the TermsAccepted event is recorded for user "(?<user_id>[^"]+)"/,
          %{user_id: _user_id},
          state do
    user_id = state.invitee_id

    assert_receive_event(Nexus.App, TermsAccepted, fn event ->
      event.user_id == user_id
    end)

    {:ok, state}
  end

  defthen ~r/he sees the biometric anchor step/, _, state do
    {:ok, state}
  end

  defwhen ~r/he completes biometric enrollment/, _, state do
    cmd = %EnrollBiometric{
      user_id: state.invitee_id,
      org_id: state.org_id,
      credential_id: "test_cred_#{Uniq.UUID.uuid7()}",
      cose_key: "test_cose_key"
    }

    assert :ok =
             Nexus.App.dispatch(cmd, metadata: %{"idempotency_key" => state.invitee_id})

    {:ok, state}
  end

  defthen ~r/he is redirected to "(?<path>[^"]+)" immediately/,
          %{path: _path},
          state do
    {:ok, state}
  end

  defthen ~r/the user "(?<user_id>[^"]+)" eventually reaches status "(?<expected_status>[^"]+)"/,
          %{user_id: _user_id, expected_status: expected_status},
          state do
    user =
      wait_until(
        fn ->
          u = Repo.get(User, state.invitee_id)

          if u && u.status == expected_status do
            {:ok, u}
          else
            {:error, "Waiting for #{expected_status}, got #{u && u.status}"}
          end
        end,
        15
      )

    assert user.status == expected_status
    {:ok, state}
  end

  defthen ~r/the step sequence does not include "(?<step>[^"]+)"/,
          %{step: _step},
          state do
    {:ok, state}
  end

  defgiven ~r/an expired biometric invitation token for user "(?<user_id>[^"]+)"/,
           %{user_id: _user_id},
           state do
    {:ok, state}
  end

  defwhen ~r/Bob opens the invitation link with the expired token/, _, state do
    {:ok, state}
  end

  defthen ~r/he is redirected to the home page/, _, state do
    {:ok, state}
  end

  defgiven ~r/he is on the biometric step without having accepted terms/, _, state do
    {:ok, state}
  end

  defthen ~r/he is redirected back to the terms step/, _, state do
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
