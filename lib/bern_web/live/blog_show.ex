defmodule BernWeb.Live.BlogShow do
  use BernWeb, :live_view

  def mount(%{"id" => id}, _session, socket) do
    post = Bern.Blog.get_post_by_id!(id)

    relevant =
      post.tags
      |> Enum.shuffle()
      |> List.first()
      |> Bern.Blog.get_posts_by_tag!()
      |> Enum.reject(& &1.id == post.id)
      |> Enum.shuffle()
      |> Enum.take(2)

    {:ok,
      socket
      |> assign(:post, post)
      |> assign(:live_seo, true)
      |> assign(:relevant_posts, relevant)
      |> assign(:page_title, post.title)}
  end
end
