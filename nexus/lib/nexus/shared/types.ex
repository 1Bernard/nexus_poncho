defmodule Nexus.Types do
  @moduledoc """
  Centralized Type Definitions for Nexus.
  Provides a single source of truth for domain-specific types.
  """

  @type money :: Decimal.t()
  @type org_id :: binary() | :all
  @type user_id :: binary()
  @type binary_id :: binary()
  @type vault_id :: binary()
  @type transfer_id :: binary()
  @type reconciliation_id :: binary()
  @type currency :: String.t()
  @type datetime :: DateTime.t()
  @type status :: String.t() | atom()
  @type credential_id :: String.t()
end
