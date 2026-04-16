defmodule NexusWeb.Repo do
  @moduledoc """
  Delegates all DB calls to the core Nexus.Repo.
  """

  # Delegate pattern as per Codex Chapter 2.4
  # Note: Removing default arguments as they are inherited from the target
  defdelegate all(queryable, opts), to: Nexus.Repo
  defdelegate get(queryable, id, opts), to: Nexus.Repo
  defdelegate get!(queryable, id, opts), to: Nexus.Repo
  defdelegate get_by(queryable, clauses, opts), to: Nexus.Repo
  defdelegate get_by!(queryable, clauses, opts), to: Nexus.Repo
  defdelegate aggregate(queryable, aggregate, field, opts), to: Nexus.Repo
  defdelegate insert(struct, opts), to: Nexus.Repo
  defdelegate insert!(struct, opts), to: Nexus.Repo
  defdelegate update(changeset, opts), to: Nexus.Repo
  defdelegate update!(changeset, opts), to: Nexus.Repo
  defdelegate insert_or_update(changeset, opts), to: Nexus.Repo
  defdelegate insert_or_update!(changeset, opts), to: Nexus.Repo
  defdelegate delete(struct, opts), to: Nexus.Repo
  defdelegate delete!(struct, opts), to: Nexus.Repo
  defdelegate delete_all(queryable, opts), to: Nexus.Repo
  defdelegate insert_all(schema_or_source, entries, opts), to: Nexus.Repo
  defdelegate update_all(queryable, updates, opts), to: Nexus.Repo
  defdelegate transaction(fun, opts), to: Nexus.Repo
  defdelegate checkout(fun, opts), to: Nexus.Repo
  defdelegate one(queryable, opts), to: Nexus.Repo
  defdelegate one!(queryable, opts), to: Nexus.Repo
  defdelegate query(sql, params, opts), to: Nexus.Repo
end
