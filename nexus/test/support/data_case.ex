defmodule Nexus.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.
  """
  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      alias Nexus.Repo
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Nexus.DataCase
    end
  end

  setup tags do
    Nexus.DataCase.setup_sandbox(tags)
    :ok
  end

  def setup_sandbox(tags) do
    if tags[:no_sandbox] do
      Sandbox.mode(Nexus.Repo, :auto)
      :ok
    else
      pid = Sandbox.start_owner!(Nexus.Repo, shared: not tags[:async])
      on_exit(fn -> Sandbox.stop_owner(pid) end)
    end
  end
end
