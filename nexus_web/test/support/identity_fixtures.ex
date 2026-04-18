defmodule Nexus.Identity.Fixtures do
  @moduledoc """
  Test fixtures for the Identity domain.
  Provides helpers to seed Identity read model records for LiveView and integration tests.
  """
  alias Nexus.Identity.Projections.{Session, User}
  alias Nexus.Repo

  def user_fixture(attrs \\ %{}) do
    user_id = Uniq.UUID.uuid7()

    params =
      Map.merge(
        %{
          id: user_id,
          org_id: Uniq.UUID.uuid7(),
          email: "#{Uniq.UUID.uuid7()}@test.nexus.com",
          name: "Test User",
          role: "user",
          status: "registered"
        },
        attrs
      )

    user = %User{} |> User.changeset(params) |> Repo.insert!()

    %{
      user_id: user.id,
      org_id: user.org_id,
      email: user.email,
      name: user.name,
      status: user.status
    }
  end

  def session_fixture(user_id, org_id, attrs \\ %{}) do
    session_id = Uniq.UUID.uuid7()
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    params =
      Map.merge(
        %{
          id: session_id,
          user_id: user_id,
          org_id: org_id,
          credential_id: "cred_#{System.unique_integer([:positive])}",
          status: "active",
          expires_at: DateTime.add(now, 86_400, :second),
          started_at: now
        },
        attrs
      )

    %Session{} |> Session.changeset(params) |> Repo.insert!()
  end
end
