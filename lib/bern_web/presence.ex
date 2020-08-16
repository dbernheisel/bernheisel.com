defmodule BernWeb.Presence do
  use Phoenix.Presence,
    otp_app: :bern,
    pubsub_server: Bern.PubSub
end
