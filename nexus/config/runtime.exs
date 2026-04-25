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

  # OpenTelemetry: W3C trace context propagation for distributed mesh
  config :opentelemetry,
    span_processor: :batch,
    text_map_propagators: [:trace_context, :baggage],
    traces_exporter: :otlp,
    resource: [{"service.name", node_name}]

  config :opentelemetry_exporter,
    otlp_protocol: :http_protobuf,
    otlp_endpoint: "http://jaeger:4318"

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

  # Functional Partitioning: controls which domain handlers start on this node.
  # These are driven by environment variables in docker-compose.yml per-node.
  get_bool = fn env_var, default ->
    case System.get_env(env_var) do
      "true" -> true
      "false" -> false
      _ -> default
    end
  end

  # Gateway Mode: when the web node runs as a standalone gateway (no Erlang distribution
  # to worker nodes), Commanded must use :local registry. This prevents the :global
  # registry from trying to synchronise across a cluster that web is not part of.
  # Also clear the libcluster topology so web doesn't repeatedly attempt connections.
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
    start_projections: get_bool.("START_PROJECTIONS", true),
    start_identity_projections: get_bool.("START_IDENTITY_PROJECTIONS", true),
    start_organization_projections: get_bool.("START_ORGANIZATION_PROJECTIONS", true),
    start_compliance_projections: get_bool.("START_COMPLIANCE_PROJECTIONS", true),
    start_accounting_projections: get_bool.("START_ACCOUNTING_PROJECTIONS", true),
    start_treasury_projections: get_bool.("START_TREASURY_PROJECTIONS", true),
    start_messaging_projections: get_bool.("START_MESSAGING_PROJECTIONS", true),
    start_onboarding_pm: get_bool.("START_ONBOARDING_PM", true),
    start_platform_audit: get_bool.("START_PLATFORM_AUDIT", true),
    start_marketing_projections: get_bool.("START_MARKETING_PROJECTIONS", true),
    start_marketing_pm: get_bool.("START_MARKETING_PM", true),
    web_host: System.get_env("WEB_HOST") || "http://localhost:4000",
    token_secret_key_base: token_secret_key_base,
    loki_url: System.get_env("LOKI_URL")
end
