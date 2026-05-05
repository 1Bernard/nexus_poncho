defmodule Nexus.Identity.Aggregates.Session do
  @moduledoc """
  Session Aggregate.
  A Session is the domain fact that a specific user was physically present
  and authenticated via their enrolled biometric hardware credential.
  Each session has its own identity (session_id) and lifecycle.
  """

  defstruct [:session_id, :user_id, :org_id, :status]

  alias __MODULE__, as: Session
  alias Nexus.Identity.Commands.{ExpireSession, StartSession}
  alias Nexus.Identity.Events.{SessionExpired, SessionStarted}
  alias NexusShared.Identity.Statuses

  require Logger

  # Compile-time constants — required for use in pattern matches
  @session_active Statuses.session_active()
  @session_expired Statuses.session_expired()

  # ── Command Handlers ──────────────────────────────────────────────────────

  def execute(%Session{session_id: nil}, %StartSession{} = cmd) do
    %SessionStarted{
      session_id: cmd.session_id,
      user_id: cmd.user_id,
      org_id: cmd.org_id,
      credential_id: cmd.credential_id,
      ip_address: cmd.ip_address,
      user_agent: cmd.user_agent,
      expires_at: cmd.expires_at
    }
  end

  def execute(%Session{session_id: id}, %StartSession{}) when not is_nil(id) do
    {:error, :session_already_exists}
  end

  def execute(%Session{status: @session_active}, %ExpireSession{} = cmd) do
    %SessionExpired{session_id: cmd.session_id, user_id: cmd.user_id, org_id: cmd.org_id}
  end

  def execute(%Session{status: @session_expired}, %ExpireSession{}) do
    {:error, :session_already_expired}
  end

  def execute(%Session{session_id: nil}, %ExpireSession{}) do
    {:error, :session_not_found}
  end

  def execute(%Session{} = state, command) do
    Logger.warning(
      "[SessionAggregate] Unhandled command #{inspect(command.__struct__)} in status #{state.status}"
    )

    {:error, :invalid_command_for_current_state}
  end

  # ── State Transitions ─────────────────────────────────────────────────────

  def apply(%Session{} = state, %SessionStarted{} = event) do
    %Session{
      state
      | session_id: event.session_id,
        user_id: event.user_id,
        org_id: event.org_id,
        status: @session_active
    }
  end

  def apply(%Session{} = state, %SessionExpired{}) do
    %Session{state | status: @session_expired}
  end
end
