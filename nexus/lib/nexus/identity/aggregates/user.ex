defmodule Nexus.Identity.Aggregates.User do
  @moduledoc """
  User Aggregate.
  Owns the user lifecycle state machine: registration → biometric enrollment
  → compliance activation → role management → deactivation.
  Follows Standard: Deterministic Engine.
  """

  defstruct [
    :user_id,
    :org_id,
    :email,
    :name,
    :role,
    :status,
    :credential_id,
    :cose_key
  ]

  alias __MODULE__, as: User

  alias Nexus.Identity.Commands.{
    ActivateUser,
    DeactivateUser,
    EnrollBiometric,
    RegisterUser,
    UpdateUserRole
  }

  alias Nexus.Identity.Events.{
    BiometricEnrolled,
    UserActivated,
    UserDeactivated,
    UserRegistered,
    UserRoleChanged
  }

  require Logger

  # ── Command Handlers ──────────────────────────────────────────────────────

  def execute(%User{user_id: nil}, %RegisterUser{} = cmd) do
    %UserRegistered{
      user_id: cmd.user_id,
      org_id: cmd.org_id,
      email: cmd.email,
      name: cmd.name,
      role: cmd.role,
      credential_id: cmd.credential_id,
      cose_key: cmd.cose_key
    }
  end

  def execute(%User{}, %RegisterUser{}) do
    {:error, :user_already_exists}
  end

  # Guard: biometric already enrolled — do not overwrite hardware credentials
  def execute(%User{credential_id: existing}, %EnrollBiometric{}) when not is_nil(existing) do
    {:error, :biometric_already_enrolled}
  end

  def execute(%User{status: status}, %EnrollBiometric{} = cmd)
      when status in ["invited", "registered", "active"] do
    %BiometricEnrolled{
      user_id: cmd.user_id,
      org_id: cmd.org_id,
      credential_id: cmd.credential_id,
      cose_key: cmd.cose_key
    }
  end

  def execute(%User{status: status}, %ActivateUser{} = cmd)
      when status in ["registered", "invited"] do
    %UserActivated{
      user_id: cmd.user_id,
      org_id: cmd.org_id,
      status: "active"
    }
  end

  def execute(%User{status: "deactivated"}, %DeactivateUser{}) do
    {:error, :user_already_deactivated}
  end

  def execute(%User{status: status}, %DeactivateUser{} = cmd)
      when status in ["invited", "registered", "active"] do
    %UserDeactivated{
      user_id: cmd.user_id,
      org_id: cmd.org_id,
      reason: cmd.reason,
      deactivated_by: cmd.deactivated_by
    }
  end

  def execute(%User{status: "active"} = user, %UpdateUserRole{} = cmd) do
    if user.role == cmd.new_role do
      {:error, :role_unchanged}
    else
      %UserRoleChanged{
        user_id: cmd.user_id,
        org_id: cmd.org_id,
        old_role: user.role,
        new_role: cmd.new_role,
        changed_by: cmd.changed_by
      }
    end
  end

  def execute(%User{}, %UpdateUserRole{}) do
    {:error, :user_not_active}
  end

  def execute(%User{} = state, command) do
    Logger.warning("[UserAggregate] Unhandled command #{inspect(command.__struct__)} in status #{inspect(state.status)}")
    {:error, :invalid_command_for_current_state}
  end

  # ── State Transitions ─────────────────────────────────────────────────────

  def apply(%User{} = state, %UserRegistered{} = event) do
    status = if event.credential_id, do: "registered", else: "invited"

    %User{
      state
      | user_id: event.user_id,
        org_id: event.org_id,
        email: event.email,
        name: event.name,
        role: event.role,
        status: status,
        credential_id: event.credential_id,
        cose_key: event.cose_key
    }
  end

  def apply(%User{} = state, %BiometricEnrolled{} = event) do
    %User{
      state
      | status: "registered",
        credential_id: event.credential_id,
        cose_key: event.cose_key
    }
  end

  def apply(%User{} = state, %UserActivated{} = event) do
    %User{state | status: event.status}
  end

  def apply(%User{} = state, %UserDeactivated{}) do
    %User{state | status: "deactivated"}
  end

  def apply(%User{} = state, %UserRoleChanged{} = event) do
    %User{state | role: event.new_role}
  end
end
