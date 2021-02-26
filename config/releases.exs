import Config

System.get_env("AUTH_USER") ||
  System.get_env("AUTH_PASS") ||
  raise "environment variable AUTH_USER and/or AUTH_PASS is missing."

secret_key_base =
  System.get_env("SECRET_KEY_BASE") ||
    raise """
    environment variable SECRET_KEY_BASE is missing.
    You can generate one by calling: mix phx.gen.secret
    """

config :bern, BernWeb.Endpoint,
  http: [port: System.get_env("PORT"), compress: true],
  url: [scheme: "https", host: System.get_env("HOST"), port: 443],
  secret_key_base: secret_key_base
