[
  import_deps: [:phoenix],
  plugins: [Phoenix.LiveView.HTMLFormatter],
  inputs: [
    "*.{heex,ex,exs}",
    "{config,test}/**/*.{heex,ex,exs}",
    "lib/nexus_web/**/*.{heex,ex,exs}"
  ]
]
