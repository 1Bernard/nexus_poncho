defmodule NexusWeb.RequestAccessController do
  use NexusWeb, :controller

  alias Nexus.Marketing.AccessRequest
  alias Nexus.Repo

  def new(conn, _params) do
    changeset = AccessRequest.changeset(%AccessRequest{}, %{})

    conn
    |> put_root_layout(html: {NexusWeb.Layouts, :marketing})
    |> put_layout(false)
    |> render(:new, changeset: changeset, submitted: false)
  end

  def create(conn, %{"access_request" => params}) do
    changeset = AccessRequest.changeset(%AccessRequest{}, params)

    case Repo.insert(changeset) do
      {:ok, _request} ->
        conn
        |> put_root_layout(html: {NexusWeb.Layouts, :marketing})
        |> put_layout(false)
        |> render(:new,
          changeset: AccessRequest.changeset(%AccessRequest{}, %{}),
          submitted: true
        )

      {:error, changeset} ->
        conn
        |> put_root_layout(html: {NexusWeb.Layouts, :marketing})
        |> put_layout(false)
        |> render(:new, changeset: changeset, submitted: false)
    end
  end
end
