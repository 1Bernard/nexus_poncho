defmodule Nexus.Messaging.Workers.EmailWorker do
  @moduledoc """
  Broadway Worker for sending emails based on domain events.
  Consumes messages asynchronously from RabbitMQ to guarantee delivery resilience.
  """
  use Broadway

  require Logger

  alias Broadway.Message
  alias Nexus.Shared.Tracing

  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module:
          {BroadwayRabbitMQ.Producer,
           queue: "nexus.emails",
           connection: [
             host: System.get_env("RABBITMQ_HOST") || "rabbitmq",
             port: String.to_integer(System.get_env("RABBITMQ_PORT") || "5672"),
             username: System.get_env("RABBITMQ_USER") || "guest",
             password: System.get_env("RABBITMQ_PASS") || "guest",
             client_properties: [{"connection_name", :longstr, "nexus.email_worker"}]
           ],
           declare: [durable: true],
           on_failure: :reject_and_requeue},
        concurrency: 2
      ],
      processors: [
        default: [concurrency: 5]
      ]
    )
  end

  @impl true
  def handle_message(_processor, %Message{data: data, metadata: metadata} = message, _context) do
    require OpenTelemetry.Tracer

    # Extract the OTel context from RabbitMQ headers to continue the trace
    headers = Map.get(metadata, :headers, [])
    Tracing.extract_from_headers(headers)

    OpenTelemetry.Tracer.with_span "Messaging.EmailWorker.process_email" do
      Logger.info("[Messaging] Processing Email Task: #{inspect(data)}")

      # In a full Elite implementation, we use Swoosh or Bamboo here.
      # We log the action to prove the Decoupled Worker is running.
      Logger.info("[Messaging] Simulated Email Sent successfully.")

      message
    end
  end
end
