defmodule NexusWeb.ConnCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      # The default endpoint for testing
      @endpoint NexusWeb.Endpoint

      use NexusWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import NexusWeb.ConnCase
    end
  end

  setup tags do
    :ok = Sandbox.checkout(Nexus.Repo)

    unless tags[:async] do
      Sandbox.mode(Nexus.Repo, {:shared, self()})
    end

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
