defmodule BernWeb.Live.BlogIndex do
  use BernWeb, :live_view

  def mount(_params, _session, socket) do
    posts = Bern.Blog.published_posts()

    {:ok,
     socket
     |> assign(:posts, posts)
     |> assign(:page_title, "Blog"), temporary_assigns: [posts: []]}
  end
end
