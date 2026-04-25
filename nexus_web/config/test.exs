import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :nexus_web, NexusWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "DgTg5el6nflzRzePMI/gHBj0H8JavSrDOCpwhpFGvJgG2BvUFW/O2vR3qcSbG2ZY",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Test environment runs as a single node — no Erlang clustering needed.
config :libcluster, topologies: []
config :nexus, Nexus.App, registry: :local

# Projectors use pooled DB connections; nexus_web tests run with manual sandbox.
# Disable the audit projector here — it is covered by the nexus Soul Audit suite.
config :nexus, start_platform_audit: false
config :nexus, start_marketing_projections: false
config :nexus, start_marketing_pm: false
