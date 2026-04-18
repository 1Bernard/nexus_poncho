import Config

# The 'Elite' Test Configuration
# Enforces absolute isolation and Docker-ready connectivity.

config :nexus, Nexus.Repo,
  database: System.get_env("DB_NAME_TEST") || "ledger_test",
  username: System.get_env("DB_USER") || "ledger",
  password: System.get_env("DB_PASS") || "ledger_password",
  hostname: System.get_env("DB_HOSTNAME") || "postgres",
  port: String.to_integer(System.get_env("DB_PORT") || "5432"),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10,
  show_sensitive_data_on_connection_error: true

config :nexus, Nexus.EventStore,
  database: System.get_env("EVENTSTORE_NAME_TEST") || "eventstore_test",
  username: System.get_env("EVENTSTORE_USER") || "ledger",
  password: System.get_env("EVENTSTORE_PASS") || "ledger",
  hostname: System.get_env("EVENTSTORE_HOSTNAME") || "postgres",
  pool_size: 10,
  column_data_type: "jsonb"

config :commanded,
  assert_receive_event_timeout: 5000,
  refute_receive_event_timeout: 1000

# Enable metrics server and automatic projections during tests when needed for integration
config :nexus,
  start_metrics_server: false,
  start_projections: true,
  start_identity_projections: true,
  start_organization_projections: false,
  start_compliance_projections: false,
  start_accounting_projections: false,
  start_treasury_projections: false,
  start_messaging_projections: false

# Decrease Logger noise for clean audit output
config :logger, level: :info

# Test environment runs as a single node — no Erlang clustering.
# Prevents Cluster.Supervisor from spamming connection warnings to non-existent nodes.
config :libcluster, topologies: []

# Commanded uses local registry in tests — no :global sync needed for single-node.
config :nexus, Nexus.App, registry: :local
