# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :bern,
  app_env: Mix.env()

config :mime, :types, %{
  "application/xml" => ["xml"],
  "application/manifest+json" => ["webmanifest"]
}

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

# Configures the endpoint
config :bern, BernWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "na+Mru8FGRc3ZJqrkXDJPqTs7RKeIynpJBteUKicIm498dIxe+Nn7G4THVH7W2fc",
  render_errors: [view: BernWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Bern.PubSub,
  live_view: [signing_salt: "KtGkqxBX"],
  rss_root: %URI{
    authority: "bernheisel.com",
    host: "bernheisel.com",
    scheme: "https",
    port: 443,
    path: nil
  }

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
