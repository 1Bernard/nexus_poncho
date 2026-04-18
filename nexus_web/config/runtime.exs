import Config

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
if config_env() != :test do
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
        {"rabbitmq_pass", "RABBITMQ_PASS"},
        {"secret_key_base", "SECRET_KEY_BASE"},
        {"web_erl_cookie", "WEB_ERL_COOKIE"}
      ] do
    if value = Map.get(vault_secrets, vault_key) do
      System.put_env(env_var, value)
    end
  end
end

# OpenTelemetry: W3C trace context propagation for distributed mesh
node_name = System.get_env("NODE_NAME") || "web"

config :opentelemetry,
  span_processor: :batch,
  text_map_propagators: [:trace_context, :baggage],
  traces_exporter: :otlp,
  resource: [{"service.name", node_name}]

config :opentelemetry_exporter,
  otlp_protocol: :http_protobuf,
  otlp_endpoint: "http://jaeger:4318"

# PromEx: web node runs on port 4003 to avoid conflict with Phoenix on 4000
metrics_server_config =
  if System.get_env("START_METRICS_SERVER") == "true" do
    [port: 4003, path: "/metrics", adapter: Bandit, protocol: :http, ip: {0, 0, 0, 0}]
  else
    :disabled
  end

config :nexus, NexusWeb.PromEx,
  metrics_server: metrics_server_config,
  grafana: [host: "http://grafana:3000", upload_dashboards: true, datasource_id: "prometheus"]

# Gateway Mode: web is a standalone command dispatcher — no Erlang distribution to workers.
# Use :local Commanded registry since there is no shared cluster to synchronise with.
# libcluster isolation is handled structurally in NexusWeb.Application — Cluster.Supervisor
# is excluded from the supervision tree when STANDALONE_GATEWAY=true.
# Note: config :libcluster, topologies: [] does NOT work here due to Elixir's config
# deep-merge treating [] as an empty keyword list that preserves existing topology keys.
if System.get_env("STANDALONE_GATEWAY") == "true" do
  config :nexus, Nexus.App, registry: :local
end

# Functional Partitioning: controls which domain handlers start on this node.
# The web node has all of these set to false in docker-compose.yml (pure gateway mode).
get_bool = fn env_var, default ->
  case System.get_env(env_var) do
    "true" -> true
    "false" -> false
    _ -> default
  end
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
  web_host: System.get_env("WEB_HOST") || "http://localhost:4000",
  token_secret_key_base: token_secret_key_base,
  loki_url: System.get_env("LOKI_URL")

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/nexus_web start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :nexus_web, NexusWeb.Endpoint, server: true
end

if config_env() == :prod do
  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :nexus_web, NexusWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :nexus_web, NexusWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :nexus_web, NexusWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.
end
