defmodule NexusWeb.PageController do
  use NexusWeb, :controller

  def home(conn, _params) do
    conn
    |> put_root_layout(html: {NexusWeb.Layouts, :marketing})
    |> put_layout(false)
    |> render(:home)
  end

  def health(conn, _params) do
    text(conn, "ok")
  end
end
