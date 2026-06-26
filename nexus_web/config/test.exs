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

# Notification handlers query the DB via the Ecto sandbox. In test mode
# the handlers run in spawned processes that don't own a sandbox connection,
# causing DBConnection.OwnershipError crashes that exhaust the supervisor's
# max_restart budget and take down NexusWeb.Endpoint before web tests run.
config :nexus_web, start_notification_handlers: false

# Use a mock WebAuthn adapter in tests — the real WaxAdapter requires Mnesia
# (initialized only by Nexus.Application, not NexusWeb.Application).
config :nexus, webauthn_adapter: Nexus.Identity.WebAuthn.MockAdapter
