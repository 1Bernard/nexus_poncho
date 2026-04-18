defmodule Nexus.Identity.UserLifecycleTest do
  @moduledoc """
  Sovereign Audit for DeactivateUser and UpdateUserRole commands.
  Verifies state machine guards and read model projections.
  """
  use Nexus.DataCase

  @moduletag :no_sandbox

  alias Nexus.Identity.Commands.{
    ActivateUser,
    DeactivateUser,
    RegisterUser,
    UpdateUserRole
  }

  alias Nexus.Identity.Projections.User

  # ── DeactivateUser ────────────────────────────────────────────────────────

  describe "DeactivateUser" do
    test "transitions an active user to deactivated in the read model" do
      {user_id, org_id} = register_and_activate()
      admin_id = Uniq.UUID.uuid7()

      :ok =
        Nexus.App.dispatch(%DeactivateUser{
          user_id: user_id,
          org_id: org_id,
          reason: "Policy violation",
          deactivated_by: admin_id
        })

      user =
        wait_until(fn ->
          case Repo.get(User, user_id) do
            %{status: "deactivated"} = u -> {:ok, u}
            _ -> {:error, "waiting for deactivated status"}
          end
        end)

      assert user.status == "deactivated"
    end

    test "can deactivate an invited user (no biometric yet)" do
      user_id = Uniq.UUID.uuid7()
      org_id = Uniq.UUID.uuid7()

      :ok =
        Nexus.App.dispatch(%RegisterUser{
          user_id: user_id,
          org_id: org_id,
          email: unique_email(),
          name: "Uninvited User",
          role: "viewer"
        })

      wait_until(fn ->
        case Repo.get(User, user_id) do
          %{status: "invited"} -> {:ok, true}
          _ -> {:error, "waiting for invited status"}
        end
      end)

      assert :ok = Nexus.App.dispatch(%DeactivateUser{user_id: user_id, org_id: org_id})
    end

    test "deactivating an already-deactivated user is rejected" do
      {user_id, org_id} = register_and_activate()

      :ok = Nexus.App.dispatch(%DeactivateUser{user_id: user_id, org_id: org_id})

      wait_until(fn ->
        case Repo.get(User, user_id) do
          %{status: "deactivated"} -> {:ok, true}
          _ -> {:error, "waiting for deactivated"}
        end
      end)

      assert {:error, :user_already_deactivated} =
               Nexus.App.dispatch(%DeactivateUser{user_id: user_id, org_id: org_id})
    end
  end

  # ── UpdateUserRole ────────────────────────────────────────────────────────

  describe "UpdateUserRole" do
    test "changes the role of an active user in the read model" do
      {user_id, org_id} = register_and_activate()
      admin_id = Uniq.UUID.uuid7()

      :ok =
        Nexus.App.dispatch(%UpdateUserRole{
          user_id: user_id,
          org_id: org_id,
          new_role: "admin",
          changed_by: admin_id
        })

      user =
        wait_until(fn ->
          case Repo.get(User, user_id) do
            %{role: "admin"} = u -> {:ok, u}
            _ -> {:error, "waiting for role update"}
          end
        end)

      assert user.role == "admin"
    end

    test "updating to the same role is rejected" do
      {user_id, org_id} = register_and_activate()

      # Initial role is "viewer" — set in register_and_activate/0
      assert {:error, :role_unchanged} =
               Nexus.App.dispatch(%UpdateUserRole{
                 user_id: user_id,
                 org_id: org_id,
                 new_role: "viewer",
                 changed_by: Uniq.UUID.uuid7()
               })
    end

    test "updating role of a non-active user is rejected" do
      user_id = Uniq.UUID.uuid7()
      org_id = Uniq.UUID.uuid7()

      # Registered but not yet activated
      :ok =
        Nexus.App.dispatch(%RegisterUser{
          user_id: user_id,
          org_id: org_id,
          email: unique_email(),
          name: "Inactive User",
          role: "viewer"
        })

      assert {:error, :user_not_active} =
               Nexus.App.dispatch(%UpdateUserRole{
                 user_id: user_id,
                 org_id: org_id,
                 new_role: "admin",
                 changed_by: Uniq.UUID.uuid7()
               })
    end
  end

  # ── Helpers ───────────────────────────────────────────────────────────────

  # Creates a user and activates them directly (bypassing the compliance PM).
  # This mirrors what the OnboardingProcessManager does in production.
  defp register_and_activate do
    user_id = Uniq.UUID.uuid7()
    org_id = Uniq.UUID.uuid7()

    :ok =
      Nexus.App.dispatch(%RegisterUser{
        user_id: user_id,
        org_id: org_id,
        email: unique_email(),
        name: "Test User",
        role: "viewer"
      })

    :ok = Nexus.App.dispatch(%ActivateUser{user_id: user_id, org_id: org_id})

    wait_until(fn ->
      case Repo.get(User, user_id) do
        %{status: "active"} -> {:ok, true}
        _ -> {:error, "waiting for active user"}
      end
    end)

    {user_id, org_id}
  end

  defp unique_email, do: "user_#{System.unique_integer([:positive])}@test.nexus.com"

  defp wait_until(fun, retries \\ 20) do
    case fun.() do
      {:ok, val} ->
        val

      {:error, _} when retries > 0 ->
        Process.sleep(200)
        wait_until(fun, retries - 1)

      {:error, reason} ->
        flunk(reason)
    end
  end
end
