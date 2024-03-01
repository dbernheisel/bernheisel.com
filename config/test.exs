import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :bern, BernWeb.Endpoint,
  http: [port: 4002],
  server: false

config :phoenix, :plug_init_mode, :runtime
# Print only warnings and errors during test
config :logger, level: :warning
