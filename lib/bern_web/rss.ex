defmodule BernWeb.Rss do
  @moduledoc "RSS Generator"
  alias BernWeb.Router.Helpers, as: Routes
  @endpoint BernWeb.Endpoint

  defstruct [:title, :author, :description, :posts, language: "en-US"]

  def generate(rss, opts \\ []) do
    []
    |> open(rss, opts)
    |> add_posts(rss)
    |> close()
  end

  def open(output, rss, opts) do
    todayer = Keyword.get(opts, :todayer, &Date.utc_today/0)
    year = todayer.().year

    [
      """
      <?xml version="1.0" encoding="UTF-8"?>
      <rss xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:content="http://purl.org/rss/1.0/modules/content/" xmlns:atom="http://www.w3.org/2005/Atom" version="2.0">
      """,
      "<channel>\n",
      """
      <atom:link href="#{Routes.robot_url(@endpoint, :rss)}" rel="self" type="application/rss+xml" />
      """,
      "<title>#{cdata(rss.title)}</title>\n",
      "<language>#{rss.language}</language>\n",
      "<description>#{cdata(rss.description)}</description>\n",
      "<pubDate>#{post_date(rss.posts)}</pubDate>\n",
      "<link>#{Routes.page_url(@endpoint, :show)}</link>\n",
      "<copyright>Copyright #{year} #{rss.author}</copyright>\n",
      "<generator>Artisinally Crafted by Yours Truly</generator>\n",
      output
    ]
  end

  def close(output) do
    [output, "</channel>\n", "</rss>\n"]
  end

  def post_date([post | _]), do: post_date(post)
  def post_date([]), do: nil

  def post_date(%{date: date}) do
    {:ok, ndt} = NaiveDateTime.new(date, ~T[00:00:00])
    ndt |> DateTime.from_naive!("America/New_York") |> Timex.format!("{RFC1123}")
  end

  def add_posts(output, rss) do
    [output | Enum.map(rss.posts, &to_item(&1, rss.author))]
  end

  def to_item(post, author) do
    [
      "<item>\n",
      "<title>#{cdata(post.title)}</title>\n",
      "<dc:creator>#{author}</dc:creator>\n",
      "<description>#{cdata(post.description)}</description>\n",
      "<link>#{Routes.blog_url(@endpoint, :show, post.id)}</link>\n",
      "<guid isPermaLink=\"true\">#{Routes.blog_url(@endpoint, :show, post.id)}</guid>\n",
      "<pubDate>#{post_date(post)}</pubDate>\n",
      "<content:encoded>#{cdata(post.body)}</content:encoded>\n",
      "</item>\n"
    ]
  end

  def cdata(content), do: "<![CDATA[#{content}]]>"
end
