defmodule Nexus.MixProject do
  use Mix.Project

  def project do
    [
      app: :nexus,
      version: "0.1.0",
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :mnesia, :commanded, :opentelemetry, :opentelemetry_exporter],
      mod: {Nexus.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:commanded, "~> 1.4"},
      {:commanded_eventstore_adapter, "~> 1.4"},
      {:commanded_ecto_projections, "~> 1.4"},
      {:eventstore, "~> 1.4"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, "~> 0.17"},
      {:jason, "~> 1.4"},
      {:typed_struct, "~> 0.3.0"},
      {:uniq, "~> 0.6.0"},
      {:decimal, "~> 2.1"},
      {:libcluster, "~> 3.3"},
      {:horde, "~> 0.9"},
      {:opentelemetry, "~> 1.3"},
      {:opentelemetry_api, "~> 1.2"},
      {:opentelemetry_exporter, "~> 1.6"},
      {:opentelemetry_process_propagator, "~> 0.2"},
      {:opentelemetry_phoenix, "~> 1.2"},
      {:opentelemetry_ecto, "~> 1.2"},
      {:prom_ex, "~> 1.11"},
      {:bandit, "~> 1.6"},
      {:plug_cowboy, "~> 2.7"},
      {:broadway_rabbitmq, "~> 0.7"},
      {:cabbage, path: "../vendor/cabbage", only: :test},
      {:gherkin, "~> 1.6", only: :test, override: true},
      {:wax_, "~> 0.7.0"},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:timescale, "~> 0.1"},
      {:uuidv7, "~> 1.0"},
      {:nexus_shared, path: "../nexus_shared"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "event_store.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      "event_store.setup": ["event_store.create", "event_store.init"],
      "test.features": ["test --only feature"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      precommit: [
        "format --check-formatted",
        "credo --strict",
        "sobelow --config",
        "compile --warnings-as-errors",
        "test"
      ]
    ]
  end
end
