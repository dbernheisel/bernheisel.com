defmodule BernWeb.LayoutView do
  use BernWeb, :view

  def seo_tags(%{live_seo: true} = assigns) do
    {module, _} = assigns.conn.private.phoenix_live_view
    BernWeb.SEO.meta(assigns.conn, module, assigns)
  end

  def seo_tags(_assigns), do: nil
end
