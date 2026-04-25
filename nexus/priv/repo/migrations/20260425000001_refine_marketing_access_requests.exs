defmodule Nexus.Repo.Migrations.RefineMarketingAccessRequests do
  use Ecto.Migration

  @doc """
  Drops the blanket email unique index introduced in the initial marketing domain migration.

  Email uniqueness is now enforced at the application layer with an active-request check:
  a prospective client may reapply after their previous request is rejected or archived.
  The aggregate's request_id guard prevents duplicate submissions within a single session.
  """
  def change do
    drop_if_exists(unique_index(:marketing_access_requests, [:email]))
  end
end
