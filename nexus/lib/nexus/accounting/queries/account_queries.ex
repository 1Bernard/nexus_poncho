defmodule Nexus.Accounting.Queries.AccountQueries do
  @moduledoc """
  Composable Ecto queries for the Accounting domain.
  Follows Standard Chapter 3: The Dependency Flow.
  """
  import Ecto.Query

  alias Nexus.Accounting.Projections.Account

  def base do
    Account
  end

  def for_org(query \\ base(), org_id) do
    where(query, org_id: ^org_id)
  end

  def by_id(query \\ base(), id) do
    where(query, id: ^id)
  end
end
