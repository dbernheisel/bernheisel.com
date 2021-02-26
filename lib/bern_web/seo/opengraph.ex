defmodule BernWeb.SEO.OpenGraph do
  @moduledoc """
  Build OpenGraph tags. This is destined for Facebook, Twitter, and Slack.

  https://developers.facebook.com/docs/sharing/webmasters/
  https://developer.twitter.com/en/docs/tweets/optimize-with-cards/overview/markup
  https://developer.twitter.com/en/docs/tweets/optimize-with-cards/overview/abouts-cards
  https://api.slack.com/reference/messaging/link-unfurling#classic_unfurl

  ## TODO

    - Tokenizer that turns HTML into sentences. re: https://github.com/wardbradt/HTMLST
    - Blog post header images
  """

  alias BernWeb.SEO.Generic
  alias BernWeb.Router.Helpers, as: Routes
  @generic %Generic{}
  @endpoint BernWeb.Endpoint

  defstruct [
    :description,
    :expires_at,
    :image_alt,
    :image_url,
    :published_at,
    :reading_time,
    :title,
    :url,
    article_section: "Software Development",
    # site = twitter handle representing the overall site.
    locale: "en_US",
    site: "@bernheisel",
    site_title: @generic.title,
    twitter_handle: "@bernheisel",
    type: "website"
  ]

  def build(conn, %Bern.Blog.Post{} = post) do
    %__MODULE__{
      url: Phoenix.Controller.current_url(conn),
      title: truncate(post.title, 70),
      type: "article",
      published_at: format_date(post.date),
      reading_time: format_time(post.reading_time),
      description: String.trim(truncate(post.description, 200))
    }
    |> put_image(post)
  end

  defp put_image(og, post) do
    file = "/images/blog/#{post.id}.png"

    exists? =
      [Application.app_dir(:bern), "/priv/static", file]
      |> Path.join()
      |> File.exists?()

    if exists? do
      %{og | image_url: Routes.static_url(@endpoint, file), image_alt: post.title}
    else
      og
    end
  end

  defp truncate(string, length) do
    if String.length(string) <= length do
      string
    else
      String.slice(string, 0..length)
    end
  end

  defp format_date(date), do: Date.to_iso8601(date)

  defp format_time(length), do: "#{length} minutes"
end
