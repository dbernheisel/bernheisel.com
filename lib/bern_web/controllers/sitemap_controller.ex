defmodule BernWeb.SitemapController do
  use BernWeb, :controller

  plug :put_layout, false

  def index(conn, _params) do
    posts = Bern.Blog.all_posts()
    conn
    |> put_resp_content_type("text/xml")
    |> render("index.xml", posts: posts)
  end
end
