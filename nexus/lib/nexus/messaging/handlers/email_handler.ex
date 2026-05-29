defmodule Nexus.Messaging.Handlers.EmailHandler do
  @moduledoc """
  Event handler that bridges domain events to RabbitMQ for async email delivery.
  Decouples the domain from the email transport layer — the domain emits events,
  this handler publishes tasks to the queue, the EmailWorker consumes and sends.
  """
  use Commanded.Event.Handler,
    application: Nexus.App,
    name: "Messaging.EmailHandler",
    consistency: :eventual

  require Logger
  require OpenTelemetry.Tracer

  alias Nexus.Identity.Events.{UserActivated, UserRegistered}
  alias Nexus.Identity.WebAuthn.BiometricInvitation
  alias Nexus.Shared.Tracing

  def handle(%UserRegistered{credential_id: nil} = event, metadata) do
    Tracing.extract_and_set_context(metadata)

    OpenTelemetry.Tracer.with_span "Handler.Messaging.EmailHandler.invitation" do
      Logger.info("[Messaging] Dispatching invitation email task for user: #{event.user_id}")

      token = BiometricInvitation.generate_token(event.user_id)
      magic_link = BiometricInvitation.magic_link(token)

      payload = %{
        user_id: event.user_id,
        email: event.email,
        name: event.name,
        action: "biometric_invitation",
        magic_link: magic_link,
        timestamp: DateTime.utc_now()
      }

      publish_to_queue("nexus.emails", payload)
    end
  end

  def handle(%UserActivated{} = event, metadata) do
    Tracing.extract_and_set_context(metadata)

    OpenTelemetry.Tracer.with_span "Handler.Messaging.EmailHandler.welcome" do
      Logger.info("[Messaging] Dispatching welcome email task for user: #{event.user_id}")

      payload = %{
        user_id: event.user_id,
        org_id: event.org_id,
        action: "welcome_email",
        timestamp: DateTime.utc_now()
      }

      publish_to_queue("nexus.emails", payload)
    end
  end

  def handle(_event, _metadata), do: :ok

  defp publish_to_queue(queue, payload) do
    amqp_connections = Application.get_env(:amqp, :connections, [])

    if Keyword.has_key?(amqp_connections, :email_dispatcher) do
      case AMQP.Application.get_channel(:email_dispatcher) do
        {:ok, chan} ->
          headers = :otel_propagator_text_map.inject([])
          AMQP.Basic.publish(chan, "", queue, Jason.encode!(payload), headers: headers)
          :ok

        {:error, reason} ->
          Logger.error("[Messaging] Failed to acquire RabbitMQ channel: #{inspect(reason)}")
          {:error, reason}
      end
    else
      Logger.debug("[Messaging] AMQP not configured, skipping publish to #{queue}")
      :ok
    end
  end
end
