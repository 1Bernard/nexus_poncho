defmodule Nexus.Identity.Aggregates.User do
  @moduledoc """
  User Aggregate.
  Handles registration, role management, and biometric state machine logic.
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
  alias Nexus.Identity.Commands.{RegisterUser, ActivateUser, EnrollBiometric}
  alias Nexus.Identity.Events.{UserRegistered, UserActivated, BiometricEnrolled}

  # --- Command Handlers ---

  def execute(%User{user_id: nil}, %RegisterUser{} = command) do
    %UserRegistered{
      user_id: command.user_id,
      org_id: command.org_id,
      email: command.email,
      name: command.name,
      role: command.role,
      credential_id: command.credential_id,
      cose_key: command.cose_key
    }
  end

  # Prevent duplicate registration
  def execute(%User{}, %RegisterUser{}), do: {:error, "user already exists"}

  def execute(%User{status: status}, %EnrollBiometric{} = command)
    when status in ["invited", "active", "registered"] do
    %BiometricEnrolled{
      user_id: command.user_id,
      org_id: command.org_id,
      credential_id: command.credential_id,
      cose_key: command.cose_key
    }
  end

  def execute(%User{status: status}, %ActivateUser{} = command)
    when status in ["registered", "invited"] do
    %UserActivated{
      user_id: command.user_id,
      org_id: command.org_id,
      status: "active"
    }
  end

  # Catch-all for unhandled commands
  def execute(%User{} = state, command) do
    IO.puts("[UserAggregate] Unhandled command #{inspect(command.__struct__)} in status #{state.status}")
    {:error, :invalid_command_for_current_state}
  end

  # --- State Transitions ---

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

  def apply(%User{} = state, %UserActivated{} = event) do
    %User{state | status: event.status}
  end

  def apply(%User{} = state, %BiometricEnrolled{} = event) do
    %User{
      state
      | status: "registered",
        credential_id: event.credential_id,
        cose_key: event.cose_key
    }
  end
end
