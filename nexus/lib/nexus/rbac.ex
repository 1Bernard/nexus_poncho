defmodule Nexus.RBAC do
  @moduledoc """
  Role-Based Access Control helpers.

  Two-plane model:
  - Platform roles: stored on identity_users.platform_role (super_admin, platform_support).
    Apply globally — no org scope.
  - Org roles: stored in the user_roles join table, scoped to org_id / subsidiary_id.
    Used for customer-facing treasury operations.

  Always go through these helpers — never pattern-match on role strings directly
  in business logic, and never check roles from LiveView assigns without calling
  through this module.
  """

  import Ecto.Query

  alias Nexus.Identity.Projections.User
  alias Nexus.Repo

  # ── Platform role checks ────────────────────────────────────────────────

  @doc """
  Returns true if the user holds any of the given platform roles.

  ## Examples

      iex> RBAC.has_platform_role?(user, :super_admin)
      true

      iex> RBAC.has_platform_role?(user, [:super_admin, :platform_support])
      true
  """
  def has_platform_role?(%User{platform_role: role}, roles) when is_list(roles) do
    to_string(role) in Enum.map(roles, &to_string/1)
  end

  def has_platform_role?(%User{platform_role: role}, single_role) do
    to_string(role) == to_string(single_role)
  end

  def has_platform_role?(_, _), do: false

  @doc "Returns true if the user is a super_admin."
  def super_admin?(%User{} = user), do: has_platform_role?(user, :super_admin)

  @doc "Returns true if the user is platform staff (any platform role)."
  def platform_staff?(%User{} = user),
    do: has_platform_role?(user, [:super_admin, :platform_support])

  # ── Org role checks (user_roles table) ──────────────────────────────────

  @doc """
  Returns true if the user holds the given org role, optionally scoped to
  an org_id or subsidiary_id.

  ## Options
  - `:org_id` — restrict check to this organisation
  - `:subsidiary_id` — restrict check to this subsidiary

  ## Examples

      iex> RBAC.has_role?(user, :treasury_manager, org_id: org_id)
      true
  """
  def has_role?(%User{id: user_id}, role_name, opts \\ []) do
    role_str = to_string(role_name)
    now = DateTime.utc_now()

    query =
      from(ur in "user_roles",
        join: r in "roles",
        on: ur.role_id == r.id,
        where:
          ur.user_id == ^user_id and
            r.name == ^role_str and
            (is_nil(ur.expires_at) or ur.expires_at > ^now)
      )

    query =
      if org_id = opts[:org_id],
        do: where(query, [ur], ur.org_id == ^org_id),
        else: query

    query =
      if sub_id = opts[:subsidiary_id],
        do: where(query, [ur], ur.subsidiary_id == ^sub_id),
        else: query

    Repo.exists?(query)
  end

  @doc """
  Returns true if the user has a specific entity-level permission.

  ## Examples

      iex> RBAC.has_entity_permission?(user, :vault, vault_id, :manage)
      true
  """
  def has_entity_permission?(%User{id: user_id}, entity_type, entity_id, permission) do
    Repo.exists?(
      from(ep in "entity_permissions",
        where:
          ep.user_id == ^user_id and
            ep.entity_type == ^to_string(entity_type) and
            ep.entity_id == ^entity_id and
            ep.permission == ^to_string(permission)
      )
    )
  end
end
