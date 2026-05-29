import Config

if config_env() != :test do
  # ============================================================
  # Vault Secret Fetch
  #
  # Reads sensitive secrets from HashiCorp Vault KV v2 at startup
  # and overrides the corresponding environment variables so all
  # downstream System.get_env/1 calls transparently get Vault values.
  #
  # Falls back to env vars silently if Vault is unreachable (e.g. CI).
  # Secrets are stored by the vault-init service at: secret/data/nexus
  # ============================================================
  vault_addr = System.get_env("VAULT_ADDR") || "http://vault:8200"
  vault_token = System.get_env("VAULT_TOKEN") || ""

  vault_secrets =
    if vault_token != "" do
      url = String.to_charlist("#{vault_addr}/v1/secret/data/nexus")
      headers = [{~c"X-Vault-Token", String.to_charlist(vault_token)}]

      :inets.start()

      case :httpc.request(:get, {url, headers}, [{:timeout, 3_000}], []) do
        {:ok, {{_, 200, _}, _, body}} ->
          case Jason.decode(body) do
            {:ok, %{"data" => %{"data" => secrets}}} -> secrets
            _ -> %{}
          end

        _ ->
          %{}
      end
    else
      %{}
    end

  # Vault values take precedence; env vars remain the fallback.
  for {vault_key, env_var} <- [
        {"db_pass", "DB_PASS"},
        {"eventstore_pass", "EVENTSTORE_PASS"},
        {"rabbitmq_pass", "RABBITMQ_PASS"},
        {"secret_key_base", "SECRET_KEY_BASE"},
        {"erl_cookie", "ERL_COOKIE"}
      ] do
    if value = Map.get(vault_secrets, vault_key) do
      System.put_env(env_var, value)
    end
  end

  node_name = System.get_env("NODE_NAME") || "nexus"

  # OpenTelemetry: W3C trace context propagation for distributed mesh.
  # SpanSanitizer runs first: redacts sensitive url.query params, strips nil
  # attributes from opentelemetry_ecto, and drops disconnect-close error spans.
  # The batch processor exports everything that passes through.
  config :opentelemetry,
    processors: [{Nexus.Telemetry.SpanSanitizer, %{}}, :batch],
    text_map_propagators: [:trace_context, :baggage],
    traces_exporter: :otlp,
    resource_detectors: [:otel_resource_env_var, :otel_resource_app_env],
    resource: [{"service.name", node_name}]

  config :opentelemetry_exporter,
    otlp_protocol: :http_protobuf,
    otlp_endpoint: System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT", "http://tempo:4318")

  # AMQP: named connections for visibility in RabbitMQ management UI.
  # 'email_dispatcher' is the producer (EmailDispatcher event handler).
  # 'email_worker' is the consumer (Broadway EmailWorker).
  amqp_conn = [
    host: System.get_env("RABBITMQ_HOST") || "rabbitmq",
    port: String.to_integer(System.get_env("RABBITMQ_PORT") || "5672"),
    username: System.get_env("RABBITMQ_USER") || "guest",
    password: System.get_env("RABBITMQ_PASS") || "guest"
  ]

  config :amqp,
    connections: [
      email_dispatcher:
        amqp_conn ++
          [client_properties: [{"connection_name", :longstr, "nexus.email_dispatcher"}]],
      email_worker:
        amqp_conn ++ [client_properties: [{"connection_name", :longstr, "nexus.email_worker"}]]
    ],
    channels: [
      email_dispatcher: [connection: :email_dispatcher]
    ]

  # PromEx: standalone metrics server for backend nodes (node1, node2)
  # Web node runs on 4003 (see nexus_web/config/runtime.exs) to avoid port conflict.
  metrics_server_config =
    if System.get_env("START_METRICS_SERVER") == "true" do
      [port: 4000, path: "/metrics", adapter: Bandit, protocol: :http, ip: {0, 0, 0, 0}]
    else
      :disabled
    end

  config :nexus, Nexus.PromEx,
    metrics_server: metrics_server_config,
    grafana: [host: "http://grafana:3000", upload_dashboards: true, datasource_id: "prometheus"]

  # Gateway Mode: Commanded must use :local registry so it doesn't attempt
  # :global sync across a cluster the web node is not part of.
  # libcluster isolation is handled in NexusWeb.Application — Cluster.Supervisor
  # is excluded from the supervision tree entirely when STANDALONE_GATEWAY=true.
  if System.get_env("STANDALONE_GATEWAY") == "true" do
    config :nexus, Nexus.App, registry: :local
  end

  token_secret_key_base =
    if config_env() == :prod do
      System.get_env("SECRET_KEY_BASE") ||
        raise "environment variable SECRET_KEY_BASE is missing. Generate with: mix phx.gen.secret"
    else
      System.get_env("SECRET_KEY_BASE") ||
        "7pX8G_q9R_z2W_m4K_v1B_j5N_s6H_d3F_g2S_l9D_k4J_h5G_f6D_s7A"
    end

  config :nexus,
    web_host: System.get_env("WEB_HOST") || "http://localhost:4000",
    token_secret_key_base: token_secret_key_base,
    loki_url: System.get_env("LOKI_URL")
end
