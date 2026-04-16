defmodule Nexus.Onboarding.ProcessManagers.OnboardingProcessManager do
  @moduledoc """
  Sovereign Onboarding Process Manager.
  Orchestrates dual-condition activation:
  1. PEP Compliance (Compliance Domain)
  2. Biometric Anchoring (Identity Domain)
  """
  use Commanded.ProcessManagers.ProcessManager,
    application: Nexus.App,
    name: __MODULE__

  alias Nexus.Identity.Events.{UserRegistered, BiometricEnrolled}
  alias Nexus.Identity.Commands.ActivateUser
  alias Nexus.Compliance.Commands.PerformPEPCheck
  alias Nexus.Compliance.Events.PEPCheckCompleted

  require Logger
  require OpenTelemetry.Tracer

  @derive Jason.Encoder
  defstruct [
    :user_id,
    :org_id,
    :pep_status,
    :biometric_status
  ]

  # ==========================================
  # Process Routing
  # ==========================================

  def interested?(%UserRegistered{user_id: id}), do: {:start, id}
  def interested?(%PEPCheckCompleted{user_id: id}), do: {:continue, id}
  def interested?(%BiometricEnrolled{user_id: id}), do: {:continue, id}
  def interested?(_), do: false

  # ==========================================
  # Command Dispatch
  # ==========================================

  # Initial Registration
  def handle(%__MODULE__{}, %UserRegistered{} = event, metadata) do
    Nexus.Shared.Tracing.extract_and_set_context(metadata)

    OpenTelemetry.Tracer.with_span "ProcessManager.RegistrationHandled" do
      Logger.info("[OnboardingPM] Handling registration for #{event.user_id}")

      # Trigger PEP Check immediately
      %PerformPEPCheck{
        screening_id: Uniq.UUID.uuid7(),
        user_id: event.user_id,
        org_id: event.org_id,
        name: event.name,
        credential_id: event.credential_id,
        cose_key: event.cose_key
      }
    end
  end

  # PEP Check Completed
  def handle(%__MODULE__{} = state, %PEPCheckCompleted{} = event, metadata) do
    Nexus.Shared.Tracing.extract_and_set_context(metadata)

    OpenTelemetry.Tracer.with_span "ProcessManager.PEPCompleted" do
      Logger.info("[OnboardingPM] PEP Check completed for #{event.user_id} with status: #{event.status}")

      if event.status == "clean" do
        maybe_activate(%{state | pep_status: :completed}, event.org_id)
      else
        Logger.warning("[OnboardingPM] PEP Flagged for #{event.user_id}. Activation halted.")
        []
      end
    end
  end

  # Biometric Enrolled (from magic link or mobile anchor)
  def handle(%__MODULE__{} = state, %BiometricEnrolled{} = event, metadata) do
    Nexus.Shared.Tracing.extract_and_set_context(metadata)

    OpenTelemetry.Tracer.with_span "ProcessManager.BiometricEnrolled" do
      Logger.info("[OnboardingPM] Biometric anchored for #{event.user_id}")
      
      maybe_activate(%{state | biometric_status: :completed}, state.org_id)
    end
  end

  defp maybe_activate(state, org_id) do
    if state.pep_status == :completed and state.biometric_status == :completed do
      Logger.info("[OnboardingPM] All conditions met for #{state.user_id}. Dispatching Activation.")
      %ActivateUser{
        user_id: state.user_id,
        org_id: org_id
      }
    else
      Logger.info("[OnboardingPM] Activation pending for #{state.user_id} (PEP: #{state.pep_status || :pending}, Bio: #{state.biometric_status || :pending})")
      []
    end
  end

  # ==========================================
  # State Mutators
  # ==========================================

  def apply(%__MODULE__{} = state, %UserRegistered{} = event) do
    # If biometrics were provided at registration, they are immediately completed.
    bio_status = if event.credential_id, do: :completed, else: :pending

    %__MODULE__{
      state
      | user_id: event.user_id,
        org_id: event.org_id,
        pep_status: :pending,
        biometric_status: bio_status
    }
  end

  def apply(%__MODULE__{} = state, %PEPCheckCompleted{} = event) do
    status = if event.status == "clean", do: :completed, else: :flagged
    %__MODULE__{state | pep_status: status}
  end

  def apply(%__MODULE__{} = state, %BiometricEnrolled{}) do
    %__MODULE__{state | biometric_status: :completed}
  end
end
