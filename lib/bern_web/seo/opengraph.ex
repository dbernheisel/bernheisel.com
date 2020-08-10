defmodule BernWeb.SEO.OpenGraph do
  @moduledoc """
  Build OpenGraph tags. This is destined for Facebook, Twitter, and Slack.

  https://developers.facebook.com/docs/sharing/webmasters/
  https://developer.twitter.com/en/docs/tweets/optimize-with-cards/overview/markup
  https://developer.twitter.com/en/docs/tweets/optimize-with-cards/overview/abouts-cards
  https://api.slack.com/reference/messaging/link-unfurling#classic_unfurl

  ## TODO

    - Tokenizer that turns HTML into sentences. re: https://github.com/wardbradt/HTMLST
    - Organizations storing facebook IDs and twitter handles
    - Events storing images
  """

  defstruct [
    :description,
    :expires_at,
    :image_alt,
    :image_url,
    :published_at,
    :reading_time,
    :title,
    :twitter_handle,
    :url,
    article_section: "Software Development",
    site: "@bernheisel",
    site_title: "David Bernheisel's Blog",
    type: "website"
  ]

  def build(conn, %Bern.Blog.Post{} = post) do
    %__MODULE__{
      url: Phoenix.Controller.current_url(conn),
      title: truncate(post.title, 70),
      type: "article",
      published_at: format_date(post, :date),
      reading_time: format_time(post.reading_time),
      description: String.trim(truncate(post.description, 200)),
    }
  end

  defp truncate(string, length) do
    if String.length(string) <= length do
      string
    else
      String.slice(string, 0..length)
    end
  end

  defp format_date(post, field) do
    post
    |> Map.get(field)
    |> Date.to_iso8601()
  end

  defp format_time(length), do: "#{length} minutes"
end
