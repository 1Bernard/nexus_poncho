import Config

# 1. General application configuration
config :nexus,
  ecto_repos: [Nexus.Repo]

# ==================== REPO ====================

config :nexus, Nexus.Repo,
  username: System.get_env("DB_USER") || "ledger",
  password: System.get_env("DB_PASS") || "ledger_password",
  hostname: System.get_env("DB_HOSTNAME") || "localhost",
  port: String.to_integer(System.get_env("DB_PORT") || "5432"),
  database: System.get_env("DB_NAME") || "ledger_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# ==================== EVENT STORE ====================

config :nexus, event_stores: [Nexus.EventStore]

config :nexus, Nexus.EventStore,
  column_data_type: "jsonb",
  schema: "event_store",
  serializer: Commanded.Serialization.JsonSerializer,
  adapter: Commanded.EventStore.Adapters.EventStore,
  username: System.get_env("EVENTSTORE_USER") || "ledger",
  password: System.get_env("EVENTSTORE_PASS") || "ledger_password",
  database: System.get_env("EVENTSTORE_NAME") || "ledger_dev",
  hostname: System.get_env("EVENTSTORE_HOSTNAME") || "localhost",
  port: String.to_integer(System.get_env("EVENTSTORE_PORT") || "5432"),
  pool_size: 10

# ==================== COMMANDED ====================

config :nexus, Nexus.App,
  event_store: [
    adapter: Commanded.EventStore.Adapters.EventStore,
    event_store: Nexus.EventStore
  ],
  pubsub: :local,
  registry: :global,
  router: Nexus.Router

# ==================== LIBCLUSTER ====================

config :libcluster,
  topologies: [
    nexus: [
      strategy: Cluster.Strategy.Epmd,
      config: [
        # Worker cluster peers. node1 and node2 form the Soul Cluster for Horde coordination.
        # The web node is isolated structurally: NexusWeb.Application excludes Cluster.Supervisor
        # from its supervision tree when STANDALONE_GATEWAY=true. config :libcluster, topologies: []
        # in runtime.exs does NOT work — Elixir's deep-merge preserves existing topology keys.
        hosts: [:"nexus@node1.nexus", :"nexus@node2.nexus"],
        timeout: 5_000
      ]
    ]
  ]

# ============= SHARED / INFRA =============

config :nexus, :env, Mix.env()

# token_secret_key_base moved to runtime.exs

# OTLP Configuration moved to runtime.exs

# PromEx configuration moved to runtime.exs

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
