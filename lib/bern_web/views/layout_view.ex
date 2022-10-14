defmodule BernWeb.LayoutView do
  use BernWeb, :view
  alias Phoenix.LiveView.JS
  @endpoint BernWeb.Endpoint
  alias BernWeb.Router.Helpers, as: Routes

  def put_urls(config) do
    %{config | site: Map.merge(config[:site], %{
      mask_icon_url: Routes.static_path(@endpoint, "/images/safari-pinned-tab.svg"),
      manifest_url: Routes.robot_path(@endpoint, :site_webmanifest)
    })}
  end

  def expand_mobile_menu do
    JS.toggle(to: "#MobileMenuContent")
    |> JS.toggle(to: "#MobileMenuIconOpen")
    |> JS.toggle(to: "#MobileMenuIconClose")
  end
end
