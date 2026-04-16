defmodule Nexus.Shared.Policy do
  @moduledoc """
  Behavior definition for domain-specific authorization policies.
  """

  @type roles :: [String.t()]
  @type user :: %{
          optional(:roles) => roles(),
          optional(:role) => String.t(),
          org_id: binary() | nil
        }
  @type action :: atom()
  @type resource :: any()

  @callback can?(user() | nil, action(), resource()) :: boolean()

  @doc """
  Checks if a user has a specific role.
  Safe for both Structs and Maps, and handles legacy single :role.
  """
  @spec has_role?(user() | nil, String.t()) :: boolean()
  def has_role?(nil, _role), do: false

  def has_role?(user, role) do
    roles = get_roles(user)
    Enum.member?(roles, role) or Enum.member?(roles, "system_admin")
  end

  @doc """
  Extracts roles from a user struct or map.
  """
  @spec get_roles(map() | struct()) :: roles()
  def get_roles(%{roles: roles}) when is_list(roles), do: roles
  def get_roles(%{role: role}) when is_binary(role), do: [role]
  def get_roles(%{"roles" => roles}) when is_list(roles), do: roles
  def get_roles(%{"role" => role}) when is_binary(role), do: [role]
  def get_roles(_), do: []
end
