%{
  title: "Querying an Embedded Map in PostgreSQL with Ecto",
  tags: ["elixir"],
  canonical_url: "https://robots.thoughtbot.com/querying-embedded-maps-in-postgresql-with-ecto",
  description: """
  Structs and maps are easy to work with in Elixir, but if they are stored
  in the database as JSON and accessed via an Ecto Schema, it's not as
  clear how to query them. We're going to explore how to do that, and make
  it clear and easy.
  """
}
---

Structs and maps are easy to work with in Elixir, but if they are stored
in the database as JSON and accessed via an Ecto Schema, it's not as
clear how to query them. We're going to explore how to do that, and make
it clear and easy.

PostgreSQL has [great support for objects stored as JSON][psql_json].
This is useful for those moments when you need to store data that could
be variably structured, such as responses from other services' APIs, or
data that frequently travels together within your relational tables.

A common trade-off for mixing scalar column data types (like `varchar`
or `integer`) with column data types that handle more-complicated
objects (like <abbr title="JavaScript Object Notation">JSON</abbr>) is
that <abbr title="Object-relational Mapping">ORMs</abbr> or data mappers
sometimes can't introspect on them for you, which means it becomes much
harder to query that data.

Using Ecto's `embedded_schema` helps introspect on those known values,
but it doesn't really assist you with querying those fields in SQL. This
is where I became extremely greatful for [Ecto's escape
hatch][fragment_link]: `fragment()`.

## Define the Struct or Map in Ecto

Let's dive into some code as an example:

I have a `Vehicle.Photo` schema that has several versions of the photo:

- craigslist_ad
- facebook_ad
- facebook\_carousel\_ad
- extra_large
- extra_small
- large
- medium
- original
- small

We decided to store the versions' <abbr title="Uniform Resource
Locators">URLs</abbr> inside a map in the database,
because we're going to use a set of the URLs at the same time inside of
an HTML `<img srcset />`. [You can read more about srcset from
MDN and how it helps with responsive images][mdn_responsive_images].

The Ecto migration looks like this:

```elixir
def up do
  alter table(:vehicle_photos) do
    add :standard_urls, :map
    add :facebook_urls, :map
    add :craigslist_urls, :map
  end
end
```

The Ecto schema looks like this:

```elixir
schema "vehicle_photos" do
  field(:file, PhotoUploader.Type)

  embeds_one :standard_urls, StandardUrls, on_replace: :update do
    field(:extra_large, :string)
    field(:extra_small, :string)
    field(:large, :string)
    field(:medium, :string)
    field(:original, :string)
    field(:small, :string)
  end

  embeds_one :facebook_urls, FacebookUrls, on_replace: :update do
    field(:hero_ad, :string)
    field(:carousel_ad, :string)
  end

  embeds_one :craigslist_urls, CraigslistUrls, on_replace: :update do
    field(:ad, :string)
  end
end
```

Since this is a known structure, Ecto can introspect on the JSON values and
cast and dump them to the appropriate Elixir data types, which is immensely
helpful. Here I am achieving that by using `embeds_one` and specifying the
struct. Once pulled from the database, Ecto will decode them.

Other times, you may not be able to do this ahead of time, so the schema
might look like this (the `api_response` field):

```elixir
schema "vehicle_photos" do
  field(:file, PhotoUploader.Type)
  field(:api_response, :map)
end
```

## Query the JSON

Continuing with the struct example schema, we found out that some of our
URLs weren't being populated like we expected, so I had to find those
photos and fix them. How do I query for them since they're stored in
PostgreSQL as JSON? We need to drop down into raw SQL:

```elixir
def where_photo_urls_have_a_null(query) do
  query
  |> where([_q], fragment(
    """
    (facebook_urls IS NULL) OR
    (facebook_urls->>'ad_version' IS NULL) OR
    (facebook_urls->>'hero_version' IS NULL) OR
    (craigslist_urls->>'ad' IS NULL)
    """
  ))
end
```

The SQL operator `->>` will leverage [PostgreSQL's JSON
functions][psql_json] to retrieve the text or integers that are stored
in the JSON. You can access them using this syntax: `column->>key`. In
my case, I needed to find if the column was null, or it wasn't null,
then to ask if the JSON object has any keys that are null.  This will
work regardless of whether you use an embedded struct or a map, because
PostgreSQL sees it as the same thing: JSON.

Here's an example that checks for substrings:

```elixir
def where_photo_url_wrong(query) do
  query
  |> where([_q], fragment(
    """
    (facebook_urls->>'hero_ad' NOT ILIKE ?) OR
    (facebook_urls->>'carousel_ad' NOT ILIKE ?) OR
    (craigslist_urls->>'ad' NOT ILIKE ?)
    """,
    "%facebook_hero_ad%",
    "%facebook_carousel_ad%",
    "%craigslist_ad%"
  ))
end
```

## Make the Query Composable

Above is all I needed for my use case, but I wondered how I could continue
querying those fields in a reusable way. For example, how do I chain these
together in an `OR` statement that uses both of these fragments?

To do that, I'll need to extract the `fragment` expressions and put them
into a macro so they can be used within Ecto's functions.

```elixir
defmodule MyProject.SampleQuery.Fragments do
  import Ecto.Query.API, only: [fragment: 1]

  defmacro photo_urls_have_a_null do
    quote do
      fragment(
        """
        (facebook_urls IS NULL) OR
        (facebook_urls->>'ad_version' IS NULL) OR
        (facebook_urls->>'hero_version' IS NULL) OR
        (craigslist_urls->>'ad' IS NULL)
        """
      )
    end
  end

  defmacro photo_urls_not_contain([hero_ad_value, carousel_ad_value, ad_value]) do
    quote do
      fragment(
        """
        (facebook_urls->>'hero_ad' NOT ILIKE ?) OR
        (facebook_urls->>'carousel_ad' NOT ILIKE ?) OR
        (craigslist_urls->>'ad' NOT ILIKE ?)
        """,
        ^"%#{unquote(hero_ad_value)}%",
        ^"%#{unquote(carousel_ad_value)}%",
        ^"%#{unquote(ad_value)}%"
      )
    end
  end
end
```

Now that those fragments are extracted, let's use them:

```elixir
import MyProject.SampleQuery.Fragments
alias MyProject.Photo

defmodule MyProject.SampleQuery do
  def find_bad_photos(query \\ Photo) do
    query
    |> where([_p], photo_urls_have_a_null())
    |> or_where([_p], photo_urls_not_contain([
      "facebook_hero_ad",
      "facebook_carousel_ad",
      "craigslist_ad"
    ]))
    |> Repo.all
  end
end
```

**Beautiful.**

If you'd like to check out the code a little more, you can see this
[sample Ecto and Phoenix repo with tests][sample_repo].

This article only explains how to query a JSON object in the database
and how it works with Ecto querying. If you're needing to store an array
of maps or structs, then check out Jon's post [Why Ecto's Way of
Storing Embedded Lists of Maps Makes Querying Hard][Jons_post].

[fragment_link]: https://hexdocs.pm/ecto/Ecto.Query.html#module-fragments
[psql_json]: https://www.postgresql.org/docs/current/functions-json.html
[mdn_responsive_images]: https://developer.mozilla.org/en-US/docs/Learn/HTML/Multimedia_and_embedding/Responsive_images
[ecto]: https://hexdocs.pm/ecto
[sample_repo]: https://github.com/dbernheisel/sample_json_ecto_queries
[Jons_post]: https://thoughtbot.com/blog/why-ecto-s-way-of-storing-embedded-lists-of-maps-makes-querying-hard
