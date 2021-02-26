defmodule BernWeb.SitemapView do
  use BernWeb, :view
  alias BernWeb.SEO.Generic
  @generic %Generic{}

  def render("sitemap.xml", %{}) do
    BernWeb.Rss.generate(%BernWeb.Rss{
      title: @generic.title,
      author: "David Bernheisel",
      description: @generic.description,
      posts: Bern.Blog.published_posts()
    })
  end

  def root_domain() do
    Application.get_env(:amgr, AmgrWeb.Endpoint)[:asset_url] || ""
  end
  def format_date(date) do
    date
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_date()
    |> to_string()
  end
end
