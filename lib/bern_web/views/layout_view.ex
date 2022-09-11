defmodule BernWeb.LayoutView do
  use BernWeb, :view
  alias Phoenix.LiveView.JS

  def expand_mobile_menu do
    JS.toggle(to: "#MobileMenuContent")
    |> JS.toggle(to: "#MobileMenuIconOpen")
    |> JS.toggle(to: "#MobileMenuIconClose")
  end
end
