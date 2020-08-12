defmodule BernWeb.RssTest do
  use ExUnit.Case
  alias BernWeb.Rss

  describe "generate/1" do
    test "output should be valid rss" do
      posts = [
        %Bern.Blog.Post{
          id: "foo-id",
          title: "Foo Title",
          body: "<p>Some words</p>",
          description: "Warning, this is only a test",
          reading_time: 2,
          tags: ["elixir", "life"],
          date: ~D[2020-01-02]
        },
        %Bern.Blog.Post{
          id: "bar-id",
          title: "Bar Title",
          body: "<p>Some words</p>",
          description: "Warning, this is only a test",
          reading_time: 2,
          tags: ["elixir", "life"],
          date: ~D[2020-01-01]
        }
      ]

      rss = %Rss{
        title: "My Blog",
        description: "Bloggin the blog stuff",
        author: "FooBear",
        posts: posts
      }

      assert rss |> Rss.generate(todayer: fn -> %{year: 2020} end) |> IO.iodata_to_binary() == """
      <?xml version="1.0" encoding="UTF-8"?>
      <rss xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:content="http://purl.org/rss/1.0/modules/content/" xmlns:atom="http://www.w3.org/2005/Atom" version="2.0">
      <channel>
      <atom:link href="http://localhost:4002/rss.xml" rel="self" type="application/rss+xml" />
      <title><![CDATA[My Blog]]></title>
      <language>en-US</language>
      <description><![CDATA[Bloggin the blog stuff]]></description>
      <pubDate>Thu, 02 Jan 2020 00:00:00 -0500</pubDate>
      <link>http://localhost:4002/</link>
      <copyright>Copyright 2020 FooBear</copyright>
      <generator>Artisinally Crafted by Yours Truly</generator>
      <item>
      <title><![CDATA[Foo Title]]></title>
      <dc:creator>FooBear</dc:creator>
      <description><![CDATA[Warning, this is only a test]]></description>
      <link>http://localhost:4002/blog/foo-id</link>
      <guid isPermaLink="true">http://localhost:4002/blog/foo-id</guid>
      <pubDate>Thu, 02 Jan 2020 00:00:00 -0500</pubDate>
      <content:encoded><![CDATA[<p>Some words</p>]]></content:encoded>
      </item>
      <item>
      <title><![CDATA[Bar Title]]></title>
      <dc:creator>FooBear</dc:creator>
      <description><![CDATA[Warning, this is only a test]]></description>
      <link>http://localhost:4002/blog/bar-id</link>
      <guid isPermaLink="true">http://localhost:4002/blog/bar-id</guid>
      <pubDate>Wed, 01 Jan 2020 00:00:00 -0500</pubDate>
      <content:encoded><![CDATA[<p>Some words</p>]]></content:encoded>
      </item>
      </channel>
      </rss>
      """
    end
  end
end
