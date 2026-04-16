defmodule Nexus.Onboarding.UserOnboardingTest do
  @moduledoc """
  Sovereign Audit for the User Onboarding Journey.
  Verifies the cross-domain orchestration between Identity and Compliance.
  """
  use Cabbage.Feature, file: "onboarding/user_onboarding.feature"
  use Nexus.DataCase
  import Commanded.Assertions.EventAssertions

  @moduletag :feature
  @moduletag :no_sandbox

  alias Nexus.Identity.Commands.RegisterUser
  alias Nexus.Identity.Projections.User
  alias Nexus.Compliance.Projections.Screening
  alias Nexus.Repo
  import Ecto.Query

  # Global setup is handled in test_helper.exs for sovereign stability.

  # ==========================================
  # Background / Given
  # ==========================================

  defgiven ~r/a new user provides their biometric signature "(?<bio>[^"]+)" and email "(?<email>[^"]+)"/,
           %{bio: bio, email: email},
           state do
    user_id = Uniq.UUID.uuid7()

    cmd = %RegisterUser{
      user_id: user_id,
      org_id: Uniq.UUID.uuid7(),
      email: "#{Uniq.UUID.uuid7()}_#{email}",
      name: "Elite User",
      role: "user",
      credential_id: "#{Uniq.UUID.uuid7()}_cred_#{bio}",
      cose_key: "dummy_key_#{bio}"
    }

    {:ok, Map.put(state, :cmd, cmd)}
  end

  # ==========================================
  # Action / When
  # ==========================================

  defwhen ~r/the RegisterUser command is dispatched/, _, state do
    # Dispatching with our required idempotency metadata
    opts = [metadata: %{"idempotency_key" => Uniq.UUID.uuid7()}]
    assert {:ok, _result} = Nexus.dispatch(state.cmd, opts)

    {:ok, state}
  end

  # ==========================================
  # Verification / Then
  # ==========================================

  defthen ~r/the OnboardingProcessManager should intercept the UserRegistered event/, _, state do
    user_id = state.cmd.user_id

    # Assert the event specifically for this user to avoid cross-test interference
    assert_receive_event(Nexus.App, Nexus.Compliance.Events.PEPCheckInitiated, fn event ->
      event.user_id == user_id
    end)

    # Verify event details
    assert_receive_event(Nexus.App, Nexus.Compliance.Events.PEPCheckInitiated, fn event -> 
      event.user_id == user_id && event.name == "Elite User"
    end)

    # Then wait for the read model for UI/projection proof
    wait_until(fn ->
      case Repo.get(User, user_id) do
        nil -> {:error, "Still waiting for user projection"}
        u -> {:ok, u}
      end
    end)

    {:ok, state}
  end

  defthen ~r/the Compliance engine should initiate a PEP check/, _, state do
    user_id = state.cmd.user_id

    # Already asserted PEPCheckInitiated in the previous step to avoid race conditions.
    
    # Wait for Compliance Read Model (Initiated by ProcessManager)
    screening =
      wait_until(fn ->
        case Repo.get_by(Screening, user_id: user_id) do
          nil -> {:error, "Still waiting for screening read model"}
          s -> {:ok, s}
        end
      end)

    # In high-performance test environments, the status might already be "clean" 
    # if the PEPWorker processed the event immediately.
    assert screening.status in ["pending", "clean"]
    {:ok, Map.put(state, :screening_id, screening.id)}
  end

  defwhen ~r/the external PEP screening returns a "(?<status>[^"]+)" status/,
          %{status: status},
          state do
    # In our Elite system, the PEPWorker handles this automatically.
    # We wait for the status to change to the expected result.
    wait_until(fn ->
      s = Repo.get(Screening, state.screening_id)

      if s.status == status do
        {:ok, s}
      else
        {:error, "Waiting for PEP status: #{status} (Current: #{s.status})"}
      end
    end)

    {:ok, state}
  end

  defthen ~r/the OnboardingProcessManager should finalize the onboarding/, _, state do
    # Verify final activation states in Compliance
    screening = Repo.get(Screening, state.screening_id)
    assert screening.status == "clean"

    # Verify final activation in Identity (The 'Elite' 2-step loop)
    # Wait for the UserActivated event to project
    user =
      wait_until(fn ->
        u = Repo.get(User, state.cmd.user_id)

        if u.status == "active" do
          {:ok, u}
        else
          {:error, "Waiting for user activation status: active (Current: #{u && u.status})"}
        end
      end)

    assert user.status == "active"
    {:ok, state}
  end

  # ==========================================
  # Helpers
  # ==========================================

  defp wait_until(fun, retries \\ 10) do
    case fun.() do
      {:ok, result} ->
        result

      {:error, _} when retries > 0 ->
        # Full second for distributed eventual consistency
        Process.sleep(1000)
        wait_until(fun, retries - 1)

      {:error, reason} ->
        flunk("Wait until failed: #{reason}")
    end
  end
end
