defmodule BernWeb.Live.Page do
  use BernWeb, :live_view

  @impl true
  def mount(_params, %{"page" => page}, socket) do
    {:ok, socket |> assign(page: page) |> assign(:page_title, String.capitalize(page))}
  end
  def mount(_params, _, socket), do: {:ok, redirect(socket, to: Routes.blog_path(socket, :index))}

  def render(assigns) do
    BernWeb.PageView.render(assigns.page <> ".html", assigns)
  end
end
