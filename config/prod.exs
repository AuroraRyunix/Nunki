import Config

# Plain HTTP on this machine (and, with NUNKI_LISTEN=lan, the hall's
# network). There is no TLS to force and no host name to pin. The socket's
# origin and every request's Host are checked against the list in
# `NunkiWeb.HostGuard` (config/config.exs), so that a web page cannot reach
# Nunki by renaming 127.0.0.1.
config :nunki, NunkiWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  server: true

config :logger, level: :info
