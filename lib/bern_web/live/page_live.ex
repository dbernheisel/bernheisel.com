defmodule BernWeb.PageLive do
  use BernWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if socket.assigns.live_action == :home do
      {:ok, redirect(socket, to: Routes.blog_path(socket, :index))}
    else
      title = socket.assigns.live_action |> to_string() |> String.capitalize()
      {:ok, assign(socket, :page_title, title)}
    end
  end

  @impl true
  def render(assigns) do
    if assigns.live_action == :home do
      ""
    else
      BernWeb.PageView.render("#{assigns.live_action}.html", assigns)
    end
  end
end
