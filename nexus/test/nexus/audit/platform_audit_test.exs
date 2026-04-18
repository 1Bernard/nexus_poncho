defmodule Nexus.Audit.PlatformAuditTest do
  @moduledoc """
  Cabbage integration tests for PlatformAuditProjector.

  Verifies that significant domain events are written to platform_audit_logs
  with the correct actor_id, domain, and event_type — enabling cross-domain
  compliance queries.
  """
  use Cabbage.Feature, file: "audit/platform_audit.feature"
  use Nexus.DataCase

  @moduletag :feature
  @moduletag :no_sandbox

  import Ecto.Query

  alias Nexus.Audit.Projections.PlatformAuditLog
  alias Nexus.Identity.Commands.{ActivateUser, RegisterUser}

  # ── GIVEN ─────────────────────────────────────────────────────────────────

  defgiven ~r/^a user registers with email "(?<email>[^"]+)"$/, %{email: email}, state do
    user_id = Uniq.UUID.uuid7()
    org_id = Uniq.UUID.uuid7()

    :ok =
      Nexus.App.dispatch(%RegisterUser{
        user_id: user_id,
        org_id: org_id,
        email: email <> "_#{System.unique_integer([:positive])}",
        name: "Audit Test User",
        role: "viewer"
      })

    wait_until(fn ->
      case Repo.get_by(PlatformAuditLog, actor_id: user_id, event_type: "user_registered") do
        nil -> {:error, "waiting for user_registered audit log"}
        _entry -> {:ok, true}
      end
    end)

    {:ok, Map.merge(state, %{user_id: user_id, org_id: org_id})}
  end

  # ── WHEN ──────────────────────────────────────────────────────────────────

  defwhen ~r/^the user is activated$/, _captures, %{user_id: user_id, org_id: org_id} = state do
    :ok = Nexus.App.dispatch(%ActivateUser{user_id: user_id, org_id: org_id})

    wait_until(fn ->
      case Repo.get_by(PlatformAuditLog, actor_id: user_id, event_type: "user_activated") do
        nil -> {:error, "waiting for user_activated audit log"}
        _entry -> {:ok, true}
      end
    end)

    {:ok, state}
  end

  # ── THEN ──────────────────────────────────────────────────────────────────

  defthen ~r/^a platform audit log entry exists with:$/, %{table: table}, state do
    log =
      Repo.get_by(PlatformAuditLog,
        actor_id: state.user_id,
        event_type: table |> Enum.find(&(&1.field == "event_type")) |> Map.get(:value)
      )

    assert log != nil

    Enum.each(table, fn %{field: field, value: value} ->
      assert Map.get(log, String.to_atom(field)) == value,
             "Expected #{field} == #{value}, got #{inspect(Map.get(log, String.to_atom(field)))}"
    end)

    {:ok, state}
  end

  defthen ~r/^the audit log entry records the user as the actor$/, _captures, state do
    log = Repo.get_by(PlatformAuditLog, actor_id: state.user_id, event_type: "user_registered")
    assert log != nil
    assert log.actor_id == state.user_id
    {:ok, state}
  end

  defthen ~r/^exactly (?<count>\d+) platform audit log entr(?:y|ies) exists for that user with event_type "(?<event_type>[^"]+)"$/,
          %{count: count, event_type: event_type},
          state do
    actual =
      Repo.aggregate(
        from(l in PlatformAuditLog,
          where: l.actor_id == ^state.user_id and l.event_type == ^event_type
        ),
        :count
      )

    assert actual == String.to_integer(count)
    {:ok, state}
  end

  # ── Helpers ───────────────────────────────────────────────────────────────

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
