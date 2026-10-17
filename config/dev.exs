import Config

# A program that speaks out loud while somebody edits a template is a
# program that gets switched off. In development it pretends, like the
# tests; NUNKI_VOICE=os (runtime.exs) gives it the machine's own voice.
config :nunki, voice_backend: Nunki.Voice.Fake

config :nunki, NunkiWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "fN1o3cA9wL0p2dT8yVq7Kb5sXz4Hj6Rm0uE2iG9lYc3Pw8Bn1Df7Qa5St4Vx6Zk2",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:nunki, ~w(--sourcemap=inline --watch)]}
  ]

config :nunki, dev_routes: true

config :logger, :default_formatter, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  debug_heex_annotations: true,
  debug_attributes: true,
  enable_expensive_runtime_checks: true
