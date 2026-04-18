defmodule Nexus.Identity.Projectors.SessionProjector do
  @moduledoc """
  Projector for the Identity Session read model.
  Builds the identity_sessions table from SessionStarted and SessionExpired events.
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    repo: Nexus.Repo,
    name: "Identity.SessionProjector"

  alias Ecto.Multi
  alias Nexus.Identity.Events.{SessionExpired, SessionStarted}
  alias Nexus.Identity.Projections.Session

  import Ecto.Query

  require Logger

  project(%SessionStarted{} = event, metadata, fn multi ->
    attrs = %{
      id: event.session_id,
      user_id: event.user_id,
      org_id: event.org_id,
      credential_id: event.credential_id,
      status: "active",
      ip_address: event.ip_address,
      user_agent: event.user_agent,
      expires_at: event.expires_at,
      started_at: metadata.created_at,
      created_at: metadata.created_at
    }

    changeset = Session.changeset(%Session{}, attrs)

    Multi.insert(multi, :start_session, changeset,
      on_conflict: :nothing,
      conflict_target: :id
    )
  end)

  project(%SessionExpired{} = event, _metadata, fn multi ->
    query = from(s in Session, where: s.id == ^event.session_id)

    Multi.update_all(multi, :expire_session, query,
      set: [
        status: "expired",
        expired_at: DateTime.utc_now()
      ]
    )
  end)
end
