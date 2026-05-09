defmodule Nexus.Onboarding.ProcessManagers.OnboardingProcessManager do
  @moduledoc """
  Sovereign Onboarding Process Manager.

  Orchestrates two distinct onboarding paths:

  Entity Admin Path (org_admin, group_treasurer):
    UserRegistered → PEP check
    TermsAccepted + BiometricEnrolled + PEP clean → pending_kyb (wait for KYB review)
    KYBReviewCompleted → ActivateUser

  Team Member Path (all other roles):
    UserRegistered → PEP check
    TermsAccepted + BiometricEnrolled + PEP clean → ActivateUser immediately

  TeamMemberInvited:
    → RegisterUser (creates the invited user record and triggers the short path)
    → EmailDispatcher sends invitation email via RabbitMQ
  """
  use Commanded.ProcessManagers.ProcessManager,
    application: Nexus.App,
    name: __MODULE__

  alias Nexus.Compliance.Commands.PerformPEPCheck
  alias Nexus.Compliance.Events.PEPCheckCompleted
  alias Nexus.Identity.Commands.{ActivateUser, RegisterUser}
  alias Nexus.Identity.Events.{BiometricEnrolled, TeamMemberInvited, UserRegistered}
  alias Nexus.Onboarding.Events.{KYBReviewCompleted, TermsAccepted}
  alias Nexus.Shared.Tracing

  require Logger
  require OpenTelemetry.Tracer

  @entity_admin_roles ~w(org_admin group_treasurer)

  @derive Jason.Encoder
  defstruct [
    :user_id,
    :org_id,
    :role,
    :pep_status,
    :biometric_status,
    :terms_status,
    :onboarding_path
  ]

  # ── Process Routing ────────────────────────────────────────────────────────

  def interested?(%UserRegistered{user_id: id}), do: {:start, id}
  def interested?(%TeamMemberInvited{user_id: id}), do: {:start, id}
  def interested?(%PEPCheckCompleted{user_id: id}), do: {:continue, id}
  def interested?(%BiometricEnrolled{user_id: id}), do: {:continue, id}
  def interested?(%TermsAccepted{user_id: id}), do: {:continue, id}
  def interested?(%KYBReviewCompleted{user_id: id}), do: {:continue, id}
  def interested?(_), do: false

  # ── Command Dispatch ───────────────────────────────────────────────────────

  def handle(%__MODULE__{}, %UserRegistered{} = event, metadata) do
    Tracing.extract_and_set_context(metadata)

    OpenTelemetry.Tracer.with_span "ProcessManager.RegistrationHandled" do
      Logger.info("[OnboardingPM] Registration for #{event.user_id} (role: #{event.role})")

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

  def handle(%__MODULE__{}, %TeamMemberInvited{} = event, metadata) do
    Tracing.extract_and_set_context(metadata)

    OpenTelemetry.Tracer.with_span "ProcessManager.TeamMemberInvited" do
      Logger.info("[OnboardingPM] Team member invited: #{event.user_id}")

      # Provision the user record and trigger the short onboarding path
      %RegisterUser{
        user_id: event.user_id,
        org_id: event.org_id,
        email: event.email,
        name: event.name,
        role: event.role,
        credential_id: nil,
        cose_key: nil
      }
    end
  end

  def handle(%__MODULE__{} = state, %PEPCheckCompleted{} = event, metadata) do
    Tracing.extract_and_set_context(metadata)

    OpenTelemetry.Tracer.with_span "ProcessManager.PEPCompleted" do
      Logger.info("[OnboardingPM] PEP status: #{event.status} for #{event.user_id}")

      if event.status == "clean" do
        maybe_advance(%{state | pep_status: :completed})
      else
        Logger.warning("[OnboardingPM] PEP flagged for #{event.user_id}. Activation halted.")
        []
      end
    end
  end

  def handle(%__MODULE__{} = state, %BiometricEnrolled{} = event, metadata) do
    Tracing.extract_and_set_context(metadata)

    OpenTelemetry.Tracer.with_span "ProcessManager.BiometricEnrolled" do
      Logger.info("[OnboardingPM] Biometric enrolled for #{event.user_id}")
      maybe_advance(%{state | biometric_status: :completed})
    end
  end

  def handle(%__MODULE__{} = state, %TermsAccepted{} = event, metadata) do
    Tracing.extract_and_set_context(metadata)

    OpenTelemetry.Tracer.with_span "ProcessManager.TermsAccepted" do
      Logger.info("[OnboardingPM] Terms accepted by #{event.user_id}")
      maybe_advance(%{state | terms_status: :completed})
    end
  end

  # KYB review completed by platform admin → activate the entity admin user
  def handle(%__MODULE__{} = state, %KYBReviewCompleted{} = event, metadata) do
    Tracing.extract_and_set_context(metadata)

    OpenTelemetry.Tracer.with_span "ProcessManager.KYBReviewCompleted" do
      Logger.info(
        "[OnboardingPM] KYB review complete for org #{event.org_id}, activating #{state.user_id}"
      )

      %ActivateUser{
        user_id: state.user_id,
        org_id: state.org_id
      }
    end
  end

  # ── State Mutators ─────────────────────────────────────────────────────────

  def apply(%__MODULE__{} = state, %UserRegistered{} = event) do
    path = if event.role in @entity_admin_roles, do: :entity_admin, else: :team_member
    bio_status = if event.credential_id, do: :completed, else: :pending

    %__MODULE__{
      state
      | user_id: event.user_id,
        org_id: event.org_id,
        role: event.role,
        pep_status: :pending,
        biometric_status: bio_status,
        terms_status: :pending,
        onboarding_path: path
    }
  end

  def apply(%__MODULE__{} = state, %TeamMemberInvited{} = event) do
    %__MODULE__{
      state
      | user_id: event.user_id,
        org_id: event.org_id,
        role: event.role,
        pep_status: :pending,
        biometric_status: :pending,
        terms_status: :pending,
        onboarding_path: :team_member
    }
  end

  def apply(%__MODULE__{} = state, %PEPCheckCompleted{} = event) do
    status = if event.status == "clean", do: :completed, else: :flagged
    %__MODULE__{state | pep_status: status}
  end

  def apply(%__MODULE__{} = state, %BiometricEnrolled{}) do
    %__MODULE__{state | biometric_status: :completed}
  end

  def apply(%__MODULE__{} = state, %TermsAccepted{}) do
    %__MODULE__{state | terms_status: :completed}
  end

  def apply(%__MODULE__{} = state, %KYBReviewCompleted{}) do
    state
  end

  # ── Private ────────────────────────────────────────────────────────────────

  defp maybe_advance(
         %{pep_status: :completed, biometric_status: :completed, terms_status: :completed} = state
       ) do
    case state.onboarding_path do
      :entity_admin ->
        Logger.info("[OnboardingPM] Entity admin #{state.user_id} awaiting KYB review.")
        # Do NOT activate yet — wait for KYBReviewCompleted
        []

      :team_member ->
        Logger.info("[OnboardingPM] Team member #{state.user_id} all conditions met. Activating.")

        %ActivateUser{
          user_id: state.user_id,
          org_id: state.org_id
        }

      _ ->
        []
    end
  end

  defp maybe_advance(state) do
    Logger.info(
      "[OnboardingPM] #{state.user_id} pending (PEP: #{state.pep_status}, Bio: #{state.biometric_status}, Terms: #{state.terms_status})"
    )

    []
  end
end
