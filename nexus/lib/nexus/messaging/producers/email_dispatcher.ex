defmodule Nexus.Messaging.Producers.EmailDispatcher do
  @moduledoc """
  Commanded EventHandler that bridges Domain Events to RabbitMQ.
  Follows Standard: Decoupled Side-Effects.
  """
  use Commanded.Event.Handler,
    application: Nexus.App,
    name: __MODULE__,
    consistency: :eventual

  require Logger

  alias Nexus.Identity.Events.{UserActivated, UserRegistered}

  @doc """
  Handle UserRegistered events and publish an 'Invitation Email' task to RabbitMQ
  if the user is in the 'invited' state (missing biometric anchors).
  """
  def handle(%UserRegistered{credential_id: nil} = event, metadata) do
    Nexus.Shared.Tracing.extract_and_set_context(metadata)

    require OpenTelemetry.Tracer
    OpenTelemetry.Tracer.with_span "Messaging.EmailDispatcher.dispatch_invitation" do
      Logger.info("[Messaging] Dispatching invitation email task for user: #{event.user_id}")

      # Generate a secure Magic Link token
      token = Nexus.Identity.WebAuthn.BiometricInvitation.generate_token(event.user_id)
      magic_link = Nexus.Identity.WebAuthn.BiometricInvitation.magic_link(token)

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
    # Elite Standard: Trace Propagation (The Optical Fiber)
    # Extract traceparent from metadata and attach it to the current process
    Nexus.Shared.Tracing.extract_and_set_context(metadata)

    require OpenTelemetry.Tracer
    OpenTelemetry.Tracer.with_span "Messaging.EmailDispatcher.dispatch" do
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
    # Use the persistent supervised connection from AMQP.Application.
    # This avoids the anti-pattern of opening a new TCP connection per event.
    case AMQP.Application.get_channel(:email_dispatcher) do
      {:ok, chan} ->
        # Inject the current OTel context into the message headers
        headers = :otel_propagator_text_map.inject([])
        AMQP.Basic.publish(chan, "", queue, Jason.encode!(payload), headers: headers)
        :ok

      {:error, reason} ->
        Logger.error("[Messaging] Failed to acquire RabbitMQ channel: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
