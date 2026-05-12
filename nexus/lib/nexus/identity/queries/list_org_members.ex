defmodule Nexus.Identity.Queries.ListOrgMembers do
  @moduledoc """
  Query to list all members of an organisation from the identity read model.
  Returns users ordered by role then name, excluding deactivated members.
  """
  import Ecto.Query
  alias Nexus.Identity.Projections.User

  def execute(org_id, opts \\ []) do
    include_deactivated = Keyword.get(opts, :include_deactivated, false)

    base =
      from(u in User,
        where: u.org_id == ^org_id,
        order_by: [asc: u.role, asc: u.name]
      )

    query =
      if include_deactivated do
        base
      else
        from(u in base, where: u.status != "deactivated")
      end

    Nexus.Repo.all(query)
  end
end
