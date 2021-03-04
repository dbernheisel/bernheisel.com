defmodule BernWeb.RobotView do
  use BernWeb, :view
  alias BernWeb.SEO.Generic
  @generic %Generic{}

  @rss BernWeb.Rss.generate(%BernWeb.Rss{
         title: @generic.title,
         author: "David Bernheisel",
         description: @generic.description,
         posts: Bern.Blog.published_posts()
       })

  def render("robots.txt", %{env: :prod}), do: ""

  def render("robots.txt", %{env: _}) do
    """
    User-agent: *
    Disallow: /
    """
  end

  def render("rss.xml", %{}), do: @rss
end
