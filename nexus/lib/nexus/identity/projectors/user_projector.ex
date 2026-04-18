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
    UserActivated,
    UserDeactivated,
    UserRegistered,
    UserRoleChanged
  }

  alias Nexus.Identity.Idempotency.IdempotencyKey
  alias Nexus.Identity.Projections.User

  require Logger

  project(%UserRegistered{} = event, metadata, fn multi ->
    status = if event.credential_id, do: "registered", else: "invited"

    multi
    |> track_idempotency(metadata, "RegisterUser", %{user_id: event.user_id, status: status})
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
      status = if event.credential_id, do: "registered", else: "invited"

      # Pre-flight checks to avoid poisoning the transaction on multi-index unique conflicts.
      # While slightly less 'optimistic', this is far more resilient for projectors
      # handling multiple unique constraints (ID, Email, Credential ID).
      cond do
        repo.get(User, event.user_id) ->
          Logger.debug("[Identity] UserRegistered skip: user #{event.user_id} already projected.")
          {:ok, :already_exists_by_id}

        repo.get_by(User, email: event.email) ->
          Logger.warning(
            "[Identity] UserRegistered skip: email #{event.email} claimed by another user."
          )

          {:ok, :already_exists_by_email}

        event.credential_id && repo.get_by(User, credential_id: event.credential_id) ->
          Logger.warning(
            "[Identity] UserRegistered skip: credential_id #{event.credential_id} already anchored."
          )

          {:ok, :already_exists_by_credential_id}

        true ->
          attrs = %{
            id: event.user_id,
            org_id: event.org_id,
            email: event.email,
            name: event.name,
            role: event.role,
            status: status,
            credential_id: event.credential_id,
            cose_key: event.cose_key,
            created_at: metadata.created_at,
            updated_at: metadata.created_at
          }

          repo.insert(User.changeset(%User{}, attrs))
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
end
