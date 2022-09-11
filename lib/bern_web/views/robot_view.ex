defmodule BernWeb.RobotView do
  use BernWeb, :view

  @generic %BernWeb.SEO.Generic{}

  def render("robots.txt", %{env: :prod}) do
    """
    User-agent: *
    Disallow: /admin
    """
  end

  def render("robots.txt", %{env: _}) do
    """
    User-agent: *
    Disallow: /
    """
  end

  def render("rss.xml", %{}) do
    BernWeb.Rss.generate(%BernWeb.Rss{
      title: @generic.title,
      author: "David Bernheisel",
      description: @generic.description,
      posts: Bern.Blog.published_posts()
    })
  end
end
