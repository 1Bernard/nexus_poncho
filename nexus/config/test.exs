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
  pool_size: 50,
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

config :nexus,
  web_host: "http://localhost:4000",
  token_secret_key_base: "test-only-secret-key-base-not-used-in-production",
  # ProjectionCoordinator uses Horde to start all projectors at boot, which
  # races against test_helper's EventStore/DB reset and Horde auto-restart
  # fights test_helper's stop→reset→restart lifecycle. Disable it here and
  # let test_helper manage projectors directly as it always has.
  start_projection_coordinator: false

# Decrease Logger noise for clean audit output
config :logger, level: :info

# Test environment runs as a single node — no Erlang clustering.
# Prevents Cluster.Supervisor from spamming connection warnings to non-existent nodes.
config :libcluster, topologies: []

# Commanded uses local registry in tests — no :global sync needed for single-node.
config :nexus, Nexus.App, registry: :local

# Oban: manual mode in tests — jobs don't run automatically.
# Use Oban.drain_queue/1 in integration tests to control execution.
config :nexus, Oban, testing: :manual
