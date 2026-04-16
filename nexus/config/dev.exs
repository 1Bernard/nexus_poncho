import Config

# The 'Elite' Development Configuration

config :nexus, Nexus.Repo,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :nexus, Nexus.EventStore,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# Metrics enabled by default in Dev
config :nexus, :start_metrics_server, true
