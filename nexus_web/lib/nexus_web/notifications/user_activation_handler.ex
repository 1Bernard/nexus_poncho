defmodule NexusWeb.Notifications.UserActivationHandler do
  @moduledoc """
  Commanded event handler that listens for UserActivated events and sends
  KYB approval emails to entity admin users (org_admin, group_treasurer).
  Team members are notified at invitation time and redirected on activation.
  """
  use Commanded.Event.Handler,
    application: Nexus.App,
    name: __MODULE__

  alias Nexus.Identity.Events.UserActivated
  alias Nexus.Identity.Queries.GetUser
  alias NexusWeb.KYBEmail

  require Logger

  @entity_admin_roles ~w(org_admin group_treasurer)

  def handle(%UserActivated{user_id: user_id, org_id: _org_id}, _metadata) do
    case GetUser.execute(user_id) do
      nil ->
        Logger.warning("[UserActivationHandler] User #{user_id} not found in projection")
        :ok

      user when user.role in @entity_admin_roles ->
        Task.start(fn -> send_kyb_approved_email(user.name, user.email) end)
        :ok

      _team_member ->
        :ok
    end
  end

  defp send_kyb_approved_email(name, email) do
    case KYBEmail.send_kyb_approved(name, email) do
      {:ok, _} ->
        Logger.info("[UserActivationHandler] KYB approved email sent to #{email}")

      {:error, reason} ->
        Logger.error(
          "[UserActivationHandler] Failed to send KYB email to #{email}: #{inspect(reason)}"
        )
    end
  end
end
