defmodule NexusWeb.Notifications.AccessRequestRejectedHandler do
  @moduledoc """
  Commanded event handler that listens for AccessRequestRejected events
  and sends a rejection notification email to the applicant.
  """
  use Commanded.Event.Handler,
    application: Nexus.App,
    name: __MODULE__

  alias Nexus.Marketing.Events.AccessRequestRejected
  alias Nexus.Marketing.Projections.AccessRequest
  alias Nexus.Repo
  alias NexusWeb.KYBEmail

  require Logger

  def handle(%AccessRequestRejected{request_id: request_id, reason: reason}, _metadata) do
    case Repo.get(AccessRequest, request_id) do
      nil ->
        Logger.warning(
          "[AccessRequestRejectedHandler] Request #{request_id} not found in projection"
        )

        :ok

      request ->
        Task.start(fn -> send_rejection_email(request.name, request.email, reason) end)
        :ok
    end
  end

  defp send_rejection_email(name, email, reason) do
    case KYBEmail.send_access_rejected(name, email, reason) do
      {:ok, _} ->
        Logger.info("[AccessRequestRejectedHandler] Rejection email sent to #{email}")

      {:error, err} ->
        Logger.error(
          "[AccessRequestRejectedHandler] Failed to send rejection email to #{email}: #{inspect(err)}"
        )
    end
  end
end
