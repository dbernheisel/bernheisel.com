defmodule SEO.OpenGraph do
  @moduledoc """
  Build OpenGraph tags. This is destined for Facebook, Twitter, and Slack.

  https://developers.google.com/search/docs/appearance/structured-data/intro-structured-data
  https://developers.facebook.com/docs/sharing/webmasters/
  https://developer.twitter.com/en/docs/tweets/optimize-with-cards/overview/markup
  https://developer.twitter.com/en/docs/tweets/optimize-with-cards/overview/abouts-cards
  https://api.slack.com/reference/messaging/link-unfurling#classic_unfurl

  ## TODO

    - Tokenizer that turns HTML into sentences. re: https://github.com/wardbradt/HTMLST
    - Blog post header images
  """

  defstruct [
    :description,
    :expires_at,
    :image_alt,
    :image_url,
    :published_at,
    :reading_time,
    :title,
    :article_section,
    :locale,
    :site,
    :site_title,
    :twitter_handle,
    :type
  ]

  @type t :: %__MODULE__{
    description: String.t(),
    image_alt: String.t(),
    image_url: String.t(),
    published_at: DateTime.t() | NaiveDateTime.t() | Date.t(),
    expires_at: DateTime.t() | NaiveDateTime.t() | Date.t(),
    reading_time: String.t(),
    title: String.t(),
    article_section: String.t(),
    locale: String.t(),
    site: String.t(),
    site_title: String.t(),
    twitter_handle: String.t(),
    type: :article | :book | :profile | :website
  }

  def new(map) when is_map(map) do
    struct = %__MODULE__{}
    struct!(struct, Map.merge(SEO.config() |> Enum.into(%{}) |> Map.take(Map.keys(struct)), map))
  end
end
