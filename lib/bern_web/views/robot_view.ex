defmodule BernWeb.RobotView do
  use BernWeb, :view

  def render("robots.txt", %{env: :prod}), do: ""
  def render("robots.txt", %{env: _}) do
    """
    User-agent: *
    Disallow: /
    """
  end

  def render("rss.xml", %{}) do
    BernWeb.Rss.generate(%BernWeb.Rss{
      title: "David Bernheisels' Blog RSS Feed",
      author: "David Bernheisel",
      description: "A blog about development",
      posts: Bern.Blog.all_posts()
    })
  end
end
