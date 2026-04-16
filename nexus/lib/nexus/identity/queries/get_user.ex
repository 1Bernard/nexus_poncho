defmodule Nexus.Identity.Queries.GetUser do
  @moduledoc """
  Query to fetch a user by their unique identity ID.
  """
  import Ecto.Query
  alias Nexus.Identity.Projections.User

  def execute(user_id) do
    from(u in User, where: u.id == ^user_id)
    |> Nexus.Repo.one()
  end
end
