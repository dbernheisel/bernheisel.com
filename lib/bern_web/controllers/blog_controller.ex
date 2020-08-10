defmodule BernWeb.BlogController do
  use BernWeb, :controller

  def show(conn, %{"id" => id}) do
    post = Bern.Blog.get_post_by_id!(id)
    relevant =
      post.tags
      |> Enum.shuffle()
      |> List.first()
      |> Bern.Blog.get_posts_by_tag!()
      |> Enum.reject(& &1.id == post.id)
      |> Enum.shuffle()
      |> Enum.take(2)

    conn
    |> assign(:post, post)
    |> assign(:relevant_posts, relevant)
    |> assign(:page_title, post.title)
    |> render("show.html")
  end

  def index(conn, _params) do
    conn
    |> assign(:posts, Bern.Blog.all_posts())
    |> render("index.html")
  end
end
