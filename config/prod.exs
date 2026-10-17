import Config

# Plain HTTP on this machine (and, with NUNKI_LISTEN=lan, the hall's
# network). There is no TLS to force and no host name to pin.
config :nunki, NunkiWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  check_origin: false,
  server: true

config :logger, level: :info
