defmodule Nexus.Identity.Projectors.UserProjector do
  @moduledoc """
  Projector for the Identity domain.
  Synchronizes business audits, idempotency records, and read models.
  Follows Standard Chapter 11: Projectors & Audit Precision.

  ## Idempotency Strategy

  This projector uses an **optimistic insert** pattern for all write operations:
  attempt the DB write directly and match on specific `Ecto.Changeset` constraint
  errors rather than querying first. This eliminates:

  - TOCTOU (time-of-check-to-time-of-use) race conditions
  - Unnecessary pre-flight SELECT queries
  - Nested guard logic that violates the coding standards

  This is the industry-standard approach for CQRS projectors in eventually-
  consistent distributed systems.
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    repo: Nexus.Repo,
    name: "Identity.UserProjector"

  alias Ecto.Multi

  alias Nexus.Identity.Events.{
    BiometricEnrolled,
    TeamMemberInvited,
    UserActivated,
    UserDeactivated,
    UserRegistered,
    UserRoleChanged
  }

  alias Nexus.Identity.Idempotency.IdempotencyKey
  alias Nexus.Identity.Projections.User
  alias Nexus.Onboarding.Events.TermsAccepted

  require Logger

  project(%UserRegistered{} = event, metadata, fn multi ->
    multi
    |> track_idempotency(metadata, "RegisterUser", %{user_id: event.user_id, status: event.status})
    |> create_user(event, metadata)
  end)

  project(%BiometricEnrolled{} = event, metadata, fn multi ->
    multi
    |> track_idempotency(metadata, "EnrollBiometric", %{
      user_id: event.user_id,
      status: "registered"
    })
    |> enroll_biometric(event, metadata)
  end)

  project(%UserActivated{} = event, metadata, fn multi ->
    multi
    |> track_idempotency(metadata, "ActivateUser", %{user_id: event.user_id, status: "active"})
    |> activate_user(event, metadata)
  end)

  project(%UserDeactivated{} = event, metadata, fn multi ->
    multi
    |> track_idempotency(metadata, "DeactivateUser", %{
      user_id: event.user_id,
      status: "deactivated"
    })
    |> deactivate_user(event)
  end)

  project(%TeamMemberInvited{} = event, metadata, fn multi ->
    multi
    |> track_idempotency(metadata, "InviteTeamMember", %{
      user_id: event.user_id,
      status: "invited"
    })
    |> create_user_from_invitation(event, metadata)
  end)

  project(%TermsAccepted{} = event, metadata, fn multi ->
    multi
    |> track_idempotency(metadata, "AcceptTerms", %{user_id: event.user_id})
    |> record_terms_accepted(event)
  end)

  project(%UserRoleChanged{} = event, metadata, fn multi ->
    multi
    |> track_idempotency(metadata, "UpdateUserRole", %{
      user_id: event.user_id,
      new_role: event.new_role
    })
    |> update_user_role(event)
  end)

  defp track_idempotency(multi, metadata, command_name, result) do
    # Extract the deterministic key assigned by the Idempotency Middleware
    id_key =
      Map.get(metadata, "idempotency_key") || Map.get(metadata, :idempotency_key) ||
        metadata.causation_id || metadata.event_id

    attrs = %{
      id: id_key,
      command_name: command_name,
      execution_result: result,
      executed_at: Nexus.Schema.utc_now()
    }

    changeset = IdempotencyKey.changeset(%IdempotencyKey{}, attrs)

    Multi.insert(multi, :"idempotency_#{metadata.event_id}", changeset,
      on_conflict: :nothing,
      conflict_target: :id
    )
  end

  # --- Private Helpers ---

  defp create_user(multi, event, metadata) do
    Multi.run(multi, :create_user, fn repo, _ ->
      attrs = %{
        id: event.user_id,
        org_id: event.org_id,
        email: event.email,
        name: event.name,
        role: event.role,
        status: event.status,
        credential_id: event.credential_id,
        cose_key: event.cose_key,
        created_at: metadata.created_at,
        updated_at: metadata.created_at
      }

      changeset = User.changeset(%User{}, attrs)

      case repo.insert(changeset, on_conflict: :nothing, conflict_target: :id) do
        {:ok, user} ->
          {:ok, user}

        {:error, %Ecto.Changeset{} = cs} ->
          # A unique constraint other than :id fired (email or credential_id already exists
          # under a different user). Log for investigation — do not crash the projector.
          Logger.warning("[Identity] UserRegistered skipped: #{inspect(cs.errors)}")
          {:ok, :constraint_conflict}
      end
    end)
  end

  defp enroll_biometric(multi, event, _metadata) do
    # Use update_all for a robust, non-poisoning update if the user exists.
    # This avoids the get-then-update pattern which can hit race conditions.
    query = from(u in User, where: u.id == ^event.user_id)

    Multi.update_all(multi, :enroll_biometric, query,
      set: [
        status: "registered",
        credential_id: event.credential_id,
        cose_key: event.cose_key,
        updated_at: DateTime.utc_now()
      ]
    )
  end

  defp activate_user(multi, event, _metadata) do
    query = from(u in User, where: u.id == ^event.user_id)

    Multi.update_all(multi, :activate_user, query,
      set: [
        status: "active",
        updated_at: DateTime.utc_now()
      ]
    )
  end

  defp deactivate_user(multi, event) do
    query = from(u in User, where: u.id == ^event.user_id)

    Multi.update_all(multi, :deactivate_user, query,
      set: [
        status: "deactivated",
        updated_at: DateTime.utc_now()
      ]
    )
  end

  defp update_user_role(multi, event) do
    query = from(u in User, where: u.id == ^event.user_id)

    Multi.update_all(multi, :update_user_role, query,
      set: [
        role: event.new_role,
        updated_at: DateTime.utc_now()
      ]
    )
  end

  defp create_user_from_invitation(multi, event, metadata) do
    Multi.run(multi, :create_invited_user, fn repo, _ ->
      attrs = %{
        id: event.user_id,
        org_id: event.org_id,
        email: event.email,
        name: event.name,
        role: event.role,
        status: "invited",
        created_at: metadata.created_at,
        updated_at: metadata.created_at
      }

      changeset = User.changeset(%User{}, attrs)

      case repo.insert(changeset, on_conflict: :nothing, conflict_target: :id) do
        {:ok, user} ->
          {:ok, user}

        {:error, %Ecto.Changeset{} = cs} ->
          Logger.warning("[Identity] TeamMemberInvited skipped: #{inspect(cs.errors)}")
          {:ok, :constraint_conflict}
      end
    end)
  end

  defp record_terms_accepted(multi, event) do
    query = from(u in User, where: u.id == ^event.user_id)

    Multi.update_all(multi, :record_terms_accepted, query,
      set: [
        terms_accepted_at: event.accepted_at,
        terms_version: event.terms_version,
        updated_at: DateTime.utc_now()
      ]
    )
  end
end
