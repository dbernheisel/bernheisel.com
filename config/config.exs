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

config :elixir, :time_zone_database, Tz.TimeZoneDatabase
config :tz, reject_time_zone_periods_before_year: 2000

# Configures the endpoint
config :bern, BernWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "na+Mru8FGRc3ZJqrkXDJPqTs7RKeIynpJBteUKicIm498dIxe+Nn7G4THVH7W2fc",
  render_errors: [view: BernWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Bern.PubSub,
  live_view: [signing_salt: "KtGkqxBX"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :esbuild,
  version: "0.14.10",
  default: [
    args: ~w[
      js/app.js
      js/vendor.js
      --bundle
      --target=es2016
      --outdir=../priv/static/assets
      --external:/fonts/*
      --external:/images/*
    ],
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  version: "3.0.11",
  default: [
    args: ~w[
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ],
    cd: Path.expand("../assets", __DIR__)
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
