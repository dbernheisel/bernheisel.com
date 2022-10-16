defmodule BernWeb.SEO do
  @moduledoc "You know, juice."
  alias BernWeb.Router.Helpers, as: Routes

  use SEO, [
    site: &__MODULE__.site_config/1,
    open_graph: SEO.OpenGraph.build(
      locale: "en_US"
    ),
    twitter: SEO.Twitter.build(
      site: "@bernheisel",
      creator: "@bernheisel"
    )
  ]

  def site_config(conn) do
    SEO.Site.build(
      title_suffix: " · Bernheisel",
      default_title: "David Bernheisel's Blog",
      description: "A blog about development",
      theme_color: "#663399",
      windows_tile_color: "#663399",
      mask_icon_color: "#663399",
      mask_icon_url: Routes.static_path(conn, "/images/safari-pinned-tab.svg"),
      manifest_url: Routes.robot_path(conn, :site_webmanifest)
    )
  end
end

defimpl SEO.OpenGraph.Build, for: Bern.Blog.Post do
  alias BernWeb.Router.Helpers, as: Routes

  def build(post, conn) do
    SEO.OpenGraph.build(
      title: SEO.Utils.truncate(post.title, 70),
      description: post.description,
      type: :article,
      type_detail: SEO.OpenGraph.Article.build(
        published_time: post.published && post.date,
        author: "David Bernheisel",
        tag: post.tags
      ),
      url: Routes.blog_url(conn, :show, post.id)
    ) |> put_image(post, conn)
  end

  defp put_image(og, post, conn) do
    file = "/images/blog/#{post.id}.png"

    exists? =
      [Application.app_dir(:bern), "/priv/static", file]
      |> Path.join()
      |> File.exists?()

    if exists? do
      %{og |
        image: SEO.OpenGraph.Image.build(
          url: Routes.static_url(conn, file),
          alt: post.title
        )
      }
    else
      og
    end
  end
end

defimpl SEO.Breadcrumb.Build, for: Bern.Blog.Post do
  alias BernWeb.Router.Helpers, as: Routes

  def build(post, conn) do
    SEO.Breadcrumb.List.build([
      %{name: "Posts", item: Routes.blog_url(conn, :index)},
      %{name: post.title, item: Routes.blog_url(conn, :show, post.id)}
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
