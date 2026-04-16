defmodule Nexus.Identity.BiometricEnrollmentTest do
  use Nexus.DataCase
  import Commanded.Assertions.EventAssertions
  alias Nexus.Identity.AuthChallengeStore
  alias Nexus.Identity.Commands.EnrollBiometric
  alias Nexus.Identity.Projections.User, as: UserProjection
  alias Nexus.Repo

  @moduletag :no_sandbox

  describe "Biometric Enrollment Handshake" do
    test "stores and retrieves a challenge in Mnesia" do
      user_id = Ecto.UUID.generate()
      # Wax requires a map (struct), so we test with a map here
      challenge = %{bytes: <<1, 2, 3, 4>>, origin: "http://localhost", rp_id: "localhost"}

      # Ensure Mnesia is happy in this test process context
      assert :ok = AuthChallengeStore.put(user_id, challenge)
      assert ^challenge = AuthChallengeStore.get(user_id)

      AuthChallengeStore.delete(user_id)
      assert nil == AuthChallengeStore.get(user_id)
    end
  end

  describe "EnrollBiometric Command Integration" do
    test "transitions user status to registered and updates read model" do
      user_id = Ecto.UUID.generate()
      email = "biometric_#{Ecto.UUID.generate()}@nexus.com"

      # 1. Dispatch RegisterUser (simulating invitation)
      :ok = Nexus.App.dispatch(%Nexus.Identity.Commands.RegisterUser{
        user_id: user_id,
        org_id: Ecto.UUID.generate(),
        email: email,
        name: "Bio Tester",
        role: "admin"
      })

      # Wait for the initial projection
      wait_until(fn ->
        case Repo.get(UserProjection, user_id) do
          nil -> {:error, "Waiting for initial user projection"}
          u -> {:ok, u}
        end
      end)

      # 2. Dispatch EnrollBiometric
      credential_id = "cred_#{Ecto.UUID.generate()}"
      cose_key = "key_#{Ecto.UUID.generate()}"
      # TenantGate only checks presence, so any org_id is acceptable here.
      org_id = Ecto.UUID.generate()

      :ok = Nexus.App.dispatch(%EnrollBiometric{
        user_id: user_id,
        org_id: org_id,
        credential_id: credential_id,
        cose_key: cose_key
      })

      # 3. Verify read model updates
      wait_until(fn ->
        case Repo.get(UserProjection, user_id) do
          %{status: status, credential_id: ^credential_id, cose_key: ^cose_key} = u
            when status in ["registered", "active"] -> {:ok, u}
          u -> {:error, "Still waiting for biometric projection: #{inspect(u && u.status)}"}
        end
      end)
    end
  end

  defp wait_until(fun, retries \\ 20) do
    case fun.() do
      {:ok, val} -> val
      {:error, _} when retries > 0 ->
        Process.sleep(200)
        wait_until(fun, retries - 1)
      {:error, reason} ->
        flunk(reason)
    end
  end
end
