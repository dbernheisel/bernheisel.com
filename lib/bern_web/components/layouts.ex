defmodule BernWeb.Layouts do
  use BernWeb, :html
  embed_templates "layouts/*"

  def expand_mobile_menu do
    JS.toggle(to: "#MobileMenuContent")
    |> JS.toggle(to: "#MobileMenuIconOpen")
    |> JS.toggle(to: "#MobileMenuIconClose")
  end
end
