defmodule Nexus.Identity.SessionLifecycleTest do
  @moduledoc """
  Sovereign Audit for the Session lifecycle.
  Verifies StartSession and ExpireSession commands against the Session aggregate,
  and confirms the SessionProjector builds the identity_sessions read model correctly.
  """
  use Nexus.DataCase

  @moduletag :no_sandbox

  alias Nexus.Identity.Commands.{ExpireSession, StartSession}
  alias Nexus.Identity.Projections.Session

  describe "StartSession" do
    test "creates a session projection with correct fields" do
      session_id = Uniq.UUID.uuid7()
      user_id = Uniq.UUID.uuid7()
      org_id = Uniq.UUID.uuid7()
      credential_id = "cred_#{Uniq.UUID.uuid7()}"
      expires_at = future_datetime(3600)

      :ok =
        Nexus.App.dispatch(%StartSession{
          session_id: session_id,
          user_id: user_id,
          org_id: org_id,
          credential_id: credential_id,
          expires_at: expires_at,
          ip_address: "10.0.0.1",
          user_agent: "TestAgent/1.0"
        })

      session =
        wait_until(fn ->
          case Repo.get(Session, session_id) do
            nil -> {:error, "waiting for session projection"}
            s -> {:ok, s}
          end
        end)

      assert session.user_id == user_id
      assert session.org_id == org_id
      assert session.credential_id == credential_id
      assert session.status == "active"
      assert session.ip_address == "10.0.0.1"
      assert session.user_agent == "TestAgent/1.0"
      assert session.expired_at == nil
    end

    test "starting the same session twice is rejected" do
      session_id = Uniq.UUID.uuid7()

      cmd = %StartSession{
        session_id: session_id,
        user_id: Uniq.UUID.uuid7(),
        org_id: Uniq.UUID.uuid7(),
        credential_id: "cred_test",
        expires_at: future_datetime(3600)
      }

      assert :ok = Nexus.App.dispatch(cmd)
      assert {:error, :session_already_exists} = Nexus.App.dispatch(cmd)
    end
  end

  describe "ExpireSession" do
    test "marks an active session as expired in the read model" do
      session_id = Uniq.UUID.uuid7()
      user_id = Uniq.UUID.uuid7()
      org_id = Uniq.UUID.uuid7()

      :ok =
        Nexus.App.dispatch(%StartSession{
          session_id: session_id,
          user_id: user_id,
          org_id: org_id,
          credential_id: "cred_#{Uniq.UUID.uuid7()}",
          expires_at: future_datetime(3600)
        })

      wait_until(fn ->
        case Repo.get(Session, session_id) do
          %{status: "active"} -> {:ok, true}
          _ -> {:error, "waiting for active session"}
        end
      end)

      :ok =
        Nexus.App.dispatch(%ExpireSession{
          session_id: session_id,
          user_id: user_id,
          org_id: org_id
        })

      session =
        wait_until(fn ->
          case Repo.get(Session, session_id) do
            %{status: "expired"} = s -> {:ok, s}
            _ -> {:error, "waiting for expired session"}
          end
        end)

      assert session.status == "expired"
      assert session.expired_at != nil
    end

    test "expiring an already-expired session is rejected" do
      session_id = Uniq.UUID.uuid7()
      user_id = Uniq.UUID.uuid7()
      org_id = Uniq.UUID.uuid7()

      :ok =
        Nexus.App.dispatch(%StartSession{
          session_id: session_id,
          user_id: user_id,
          org_id: org_id,
          credential_id: "cred_test",
          expires_at: future_datetime(3600)
        })

      :ok =
        Nexus.App.dispatch(%ExpireSession{
          session_id: session_id,
          user_id: user_id,
          org_id: org_id
        })

      assert {:error, :session_already_expired} =
               Nexus.App.dispatch(%ExpireSession{
                 session_id: session_id,
                 user_id: user_id,
                 org_id: org_id
               })
    end

    test "expiring a non-existent session is rejected" do
      assert {:error, :session_not_found} =
               Nexus.App.dispatch(%ExpireSession{
                 session_id: Uniq.UUID.uuid7(),
                 user_id: Uniq.UUID.uuid7(),
                 org_id: Uniq.UUID.uuid7()
               })
    end
  end

  # ── Helpers ───────────────────────────────────────────────────────────────

  defp future_datetime(seconds) do
    DateTime.utc_now()
    |> DateTime.add(seconds, :second)
    |> DateTime.truncate(:microsecond)
  end

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
