defmodule BernWeb.SEO do
  @moduledoc "You know, juice."
  use BernWeb, :verified_routes

  use SEO,
    site: &__MODULE__.site_config/1,
    open_graph: SEO.OpenGraph.build(locale: "en_US"),
    twitter:
      SEO.Twitter.build(
        site: "@bernheisel",
        creator: "@bernheisel"
      )

  def site_config(_conn) do
    SEO.Site.build(
      title_suffix: " · Bernheisel",
      default_title: "David Bernheisel's Blog",
      description: "A blog about development",
      theme_color: "#663399",
      windows_tile_color: "#663399",
      mask_icon_color: "#663399",
      mask_icon_url: static_url(@endpoint, "/images/safari-pinned-tab.svg"),
      manifest_url: url(@endpoint, ~p"/site.webmanifest")
    )
  end
end

defimpl SEO.OpenGraph.Build, for: Bern.Blog.Post do
  use BernWeb, :verified_routes

  def build(post, conn) do
    SEO.OpenGraph.build(
      title: SEO.Utils.truncate(post.title, 70),
      description: post.description,
      type: :article,
      type_detail:
        SEO.OpenGraph.Article.build(
          published_time: post.published && post.date,
          author: "David Bernheisel",
          tag: post.tags
        ),
      url: url(conn, ~p"/blog/#{post}"),
      image: image(post, conn)
    )
  end

  defp image(post, conn) do
    file = "/images/blog/#{post.id}.png"

    exists? =
      [:code.priv_dir(:bern), "static", file]
      |> Path.join()
      |> File.exists?()

    if exists? do
      SEO.OpenGraph.Image.build(
        url: static_url(conn, file),
        alt: post.title
      )
    end
  end
end

defimpl SEO.Breadcrumb.Build, for: Bern.Blog.Post do
  use BernWeb, :verified_routes

  def build(post, conn) do
    SEO.Breadcrumb.List.build([
      %{name: "Posts", item: url(conn, ~p"/blog")},
      %{name: post.title, item: url(conn, ~p"/blog/#{post}")}
    ])
  end
end

defimpl SEO.Twitter.Build, for: Bern.Blog.Post do
  def build(_post, _conn) do
    SEO.Twitter.build(card: :summary_large_image)
  end
end

defimpl SEO.Site.Build, for: Bern.Blog.Post do
  def build(post, _conn) do
    SEO.Site.build(
      title: SEO.Utils.truncate(post.title, 70),
      description: post.description,
      canonical_url: post.canonical_url
    )
  end
end

defimpl SEO.Unfurl.Build, for: Bern.Blog.Post do
  def build(post, _conn) do
    if post.published do
      SEO.Unfurl.build(
        label1: "Reading Time",
        data1: format_time(post.reading_time),
        label2: "Published",
        data2: Date.to_iso8601(post.date)
      )
    end
  end

  defp format_time(length), do: "#{length} minutes"
end
