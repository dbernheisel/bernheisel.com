defmodule Bern.Blog.Post do
  @enforce_keys [:id, :title, :body, :description, :reading_time, :tags, :date]

  defstruct [
    :id,
    :title,
    :body,
    :description,
    :canonical_url,
    :reading_time,
    :tags,
    :date,
    :discussion_url,
    published: true
  ]

  def build(filename, attrs, body) do
    [
      <<year::bytes-size(4), month::bytes-size(2), day::bytes-size(2)>>,
      slug
    ] =
      filename
      |> Path.rootname()
      |> Path.split()
      |> List.last()
      |> String.split("-", parts: 2)

    struct!(
      __MODULE__,
      [
        id: slug,
        date: Date.from_iso8601!("#{year}-#{month}-#{day}"),
        body: body,
        reading_time: estimate_reading_time(body)
      ] ++ Map.to_list(attrs)
    )
  end

  @avg_wpm 200
  defp estimate_reading_time(body) do
    body
    |> String.split(" ")
    |> Enum.count()
    |> then(&(&1 / @avg_wpm))
    |> round()
  end
end

defimpl SEO.Build, for: Bern.Blog.Post do
  alias BernWeb.Router.Helpers, as: Routes
  @endpoint BernWeb.Endpoint

  def to_breadcrumb_list(post) do
    SEO.Breadcrumb.List.new([
      SEO.Breadcrumb.Item.new(
        name: "Posts",
        "@id": Routes.blog_url(@endpoint, :index)
      ),
      SEO.Breadcrumb.Item.new(
        name: post.title,
        "@id": Routes.blog_url(@endpoint, :show, post.id)
      )
    ])
  end

  def to_open_graph(post) do
    %{
      title: SEO.Utils.truncate(post.title, 70),
      type: :article,
      published_at: SEO.format_date(post.date),
      reading_time: "#{post.reading_time} minutes",
      description: SEO.Utils.truncate(post.description, 200)
    }
    |> put_image(post)
    |> SEO.OpenGraph.new()
  end

  defp put_image(og, post) do
    file = "/images/blog/#{post.id}.png"

    exists? =
      [Application.app_dir(:bern), "/priv/static", file]
      |> Path.join()
      |> File.exists?()

    if exists? do
      og
      |> Map.put(:image_url, Routes.static_url(@endpoint, file))
      |> Map.put(:image_alt, post.title)
    else
      og
    end
  end
end
