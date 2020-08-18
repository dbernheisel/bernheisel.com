%{
  title: "HTTPoison and Decompression",
  tags: ["elixir"],
  description: """
  I learned the hard way that the popular HTTP client for Elixir doesn't
  automatically decompress or re-encode responses. I had to fix it myself.
  """
}
---

Did you know that Ruby's
[Net::HTTP](https://ruby-doc.org/stdlib-2.6.3/libdoc/net/http/rdoc/Net/HTTP.html#class-Net::HTTP-label-Compression)
class automatically decompresses responses? It handles a lot of use cases that
we don't have to remember ourselves. It's built into Ruby!

When I came across a JSON API service that was returning binary, I was a bit
puzzled; "what is this binary? I'm supposed to be getting text back..." and,
it's not consistent either: sometimes I get text _on the same exact request_ a
minute later. Baffling.

On top of that, I was using [ExVCR] in some tests which serializes the
request/response chain into JSON. ExVCR takes binary responses, encodes it into
Erlang Term format, then Base64 encodes that, and then puts _that_ in the JSON
file it writes; and does all that in reverse when it's replaying the "cassette"
when the tests run.

I've seen text before on this endpoint, and now I'm getting binary
sometimes; and wait-a-second, don't HTTP clients decompress responses? I'm
pretty sure I didn't worry about this with Ruby's Net::HTTP or HTTParty.

Turns out, in the Elixir ecosystem, HTTPoison along with other common HTTP
clients like HTTPotion, the new Mint, Gun, and probably others don't do this
automatically.

## Let's back up

HTTP requests and responses have some headers that tell the client/server what
format of content we're looking for. The ones we care about here is
**[Accept-Encoding]** and **[Content-Encoding]**. There's another one
that's related called **[Content-Type]**, but that's not exactly about
compression, but we'll get to this one later.

Accept-Encoding is what the client will use to say "YO SERVER! I need some of
this resource, and I can handle it compressed with [brotli]"

Content-Encoding is what the server will respond with, as in "Oh hay Client!
Nice to see you; here's your content as requested. I even compressed it in
brotli"

What _REALLY_ happens (in my experience), is that Accept-Encoding is ignored,
and **the server's gonna give whatever it wants to you**. To complicate it more,
there are layers between the client and server that may compress data and modify
headers (or not). So, the server might have sent plaintext and provided a
Content-Encoding of `identity` or not a Content-Encoding at all (both of these
mean there is no compression.), but a load balancer, router, CDN, whatever,
might have compressed the body of data on the way back from the server to the
client.

So what's the client to do? It has to guess. This is probably why some clients
don't automatically decompress data for you.

Here are some of the options for `Content-Encoding`:

| value      |  meaning                                                            |
|------------|----------------------------------------------------------------------|
| `gzip`     | Compressed with Lempel-Ziv (LZ77). On desktops, this is a `.gz` file |
| `x-gzip`   | Same as above, just an older expression                              |
| `compress` | Compressed with Lempel-Ziv-Welch (LZW)                               |
| `deflate`  | Compressed with zlib. On desktops, this is a normal `.zip` file      |
| `br`       | Compressed with brotli.                                              |
| `identity` | No compression                                                       |
| (missing)  | No compression                                                       |

As an interesting sidenote, Phoenix supports compression into Brotli, but
otherwise there's not yet built-in support for decompressing Brotli in
Erlang/Elixir. There's also no built-in support for LZW, but that's ok because
it's not as good or popular as the other formats. The only built-ins for Erlang
and Elixir are `gzip` and `deflate` so that's what I'll support on this first
iteration.

## HTTPoison

In Elixir, the most popular HTTP client is [HTTPoison] according to [hex.pm].
Actually, let me clarify: HTTPoison itself doesn't do any HTTP requests itself;
what I mean is it's a wrapper for the Erlang HTTP client called [hackney] which
actually does the HTTP requests, and HTTPoison wraps around that to make the API
a bit friendlier for Elixir.

Let me re-word that for my use-case: I'm making a wrapper for a wrapper.

I'm not the first to notice that it doesn't decompress responses automatically.
There's been an [issue](https://github.com/edgurgel/httpoison/issues/81) open
since 2015 for them to auto-decompress, but the author has decided, (me
paraphrasing), "I'm not going to do it, but hackney is so we'll get to benefit
from it soon enough!", and _that_
[issue](https://github.com/benoitc/hackney/issues/155) has been open for a since
Jan 2015. We're still waiting. It's June 2019. 4.5 years.

Ok, cool, but I need to handle this now, and it doesn't seem like there's
movement in the popular library of choice.

## It's a little unfair

It's unfair for me to suggest these libraries should absolutely support
decompression out of the box, because these clients are really powerful. They
also support streaming which complicates decompression. But, for simple JSON
request/responses and for most APIs, we're not streaming.

Major props for these libraries making my life easier; my issue is that I didn't
know about these concepts before diving in, and through an issue I learned
about HTTP decompression.

![TIL](/images/til.gif)

## One more problem: Character Encoding

I am also working with an API service that responds with characters encoded in
ISO-8859-1 sometimes; not in UTF-8. In Elixir, strings are UTF-8 so I need to
make sure I can convert those characters to something readable for my logs, and
ultimately the clients. This character encoding is indicated in the HTTP header
[Content-Type], paired with the format of content, like JSON or XML. It's going
to look something like `text/plain;charset=utf-8` or
`application/json;charset=ISO-8859-1`.

## Let's do it

Let's stick with HTTPoison out of pure laziness. If you're implementing from
scratch, I'd recommend you to look at [Mint] first because it has no
dependencies and has a better philosophy with OTP, which is a _good thing_.
[Tesla] is also a good HTTP client to consider.

Let me re-word that again: I'm going to write a wrapper (MyApp.HTTPClient) for a
wrapper (HTTPoison) of hackney for a wrapper (my layer that covers the 3rd party
API) of a 3rd party service. Exciting.

Also please know that my project also includes Phoenix and Plug, so you might
see some helpers in the tests and implementation. If you're not using Phoenix or
Plug, it should be pretty easy to replace these functions with your own.

## My interface

It's going to be exactly like HTTPoison's. Creative, I know. But, this way I can
replace any usage of `HTTPoison.get` or `HTTPoison.post` with my own
`HttpClient.get` or `HttpClient.post`. Easy peasy.

I'm also going to give room for dependency-injection so I can test this easily.
And, maybe one day I won't want to use HTTPoison anymore, so this new interface
might also help transition my app to another HTTP client without disrupting too
much.

Let's write tests first:

```elixir
defmodule MyApp.HttpClientTest do
  use MyApp.DataCase, async: true
  import ExUnit.CaptureLog
  alias MyApp.HTTPClient
  require HTTPoison

  # I used Erlang's :zlib.gzip("Hello")
  @gzipped_response <<31, 139, 8, 0, 0, 0, 0, 0, 0, 3, 243, 72, 205, 201, 201, 7, 0, 130, 137, 209, 247, 5, 0, 0, 0>>
  # I used Erlang's :zlib.zip("Hello")
  @zipped_response <<243, 72, 205, 201, 201, 7, 0>>
  @decoded "Hello"

  describe "get" do
    test "decompresses a gzipped body" do
      requester = fn _url, _headers, _options ->
        {:ok, %HTTPoison.Response{
          body: @gzipped_response,
          headers: [{"Content-Encoding", "gzip"}]
        }}
      end

      assert {:ok, %{body: @decoded}} = HTTPClient.get(nil, [], requester: requester)
    end

    test "decompresses a gzipped body with x-gzip header" do
      requester = fn _url, _headers, _options ->
        {:ok, %HTTPoison.Response{
          body: @gzipped_response,
          headers: [{"Content-Encoding", "x-gzip"}]
        }}
      end

      assert {:ok, %{body: @decoded}} = HTTPClient.get(nil, [], requester: requester)
    end

    test "does not attempt to decompress a plain body with gzip header" do
      body = "Hallo"
      requester = fn _url, _headers, _options ->
        {:ok, %HTTPoison.Response{
          body: body,
          headers: [{"Content-Encoding", "gzip"}]
        }}
      end

      assert {:ok, %{body: ^body}} = HTTPClient.get(nil, [], requester: requester)
    end

    test "decompresses a zipped body" do
      requester = fn _url, _headers, _options ->
        {:ok, %HTTPoison.Response{
          body: @zipped_response,
          headers: [{"Content-Encoding", "deflate"}]
        }}
      end

      assert {:ok, %{body: @decoded}} = HTTPClient.get(nil, [], requester: requester)
    end

    test "emits log when encountering unsupported compression" do
      requester = fn _url, _headers, _options ->
        {:ok, %HTTPoison.Response{
          body: "Hallo",
          headers: [{"Content-Encoding", "br"}]
        }}
      end

      assert capture_log(fn ->
        assert {:ok, _} = HTTPClient.get(nil, [], requester: requester)
      end) =~ "No support for decompression of body using 'br' algorithm"
    end

    test "emits log when failing to decompress" do
      requester = fn _url, _headers, _options ->
        {:ok, %HTTPoison.Response{
          body: <<1, 2, 3>>,
          headers: [{"Content-Encoding", "deflate"}]
        }}
      end

      assert capture_log(fn ->
        assert {:ok, _} = HTTPClient.get(nil, [], requester: requester)
      end) =~ "Failed to decompress response"
    end

    test "re-encodes a latin1 body to UTF-8" do
      latin1 = <<163, 233, 100, 117, 102, 102>>
      utf8 = "£éduff"
      requester = fn _url, _headers, _options ->
        {:ok, %HTTPoison.Response{
          body: latin1,
          headers: [{"Content-Type", "text/plain;charset=ISO-8859-1"}]
        }}
      end

      assert {:ok, %{body: ^utf8}} = HTTPClient.get(nil, [], requester: requester)
    end

    test "does not re-encode utf8 bodies" do
      utf8 = "£éduff"
      requester = fn _url, _headers, _options ->
        {:ok, %HTTPoison.Response{
          body: utf8,
          headers: [{"Content-Type", "text/plain;charset=utf-8"}]
        }}
      end

      assert {:ok, %{body: ^utf8}} = HTTPClient.get(nil, [], requester: requester)
    end

    test "emits log when encountering unknown encoding" do
      requester = fn _url, _headers, _options ->
        {:ok, %HTTPoison.Response{
          body: "Hallo",
          headers: [{"Content-Type", "text/plain;charset=duurf"}]
        }}
      end

      assert capture_log(fn ->
        assert {:ok, _} = HTTPClient.get(nil, [], requester: requester)
      end) =~ "Need to implement re-encoding support for: duurf"
    end

    test "emits log when failing to reencode" do
      body = <<163, 233, 100, 117, 102, 102, 833::3>>
      requester = fn _url, _headers, _options ->
        {:ok, %HTTPoison.Response{
          body: body,
          headers: [{"Content-Type", "text/plain;charset=ISO-8859-1"}]
        }}
      end

      assert capture_log(fn ->
        assert {:ok, _} = HTTPClient.get(nil, [], requester: requester)
      end) =~ "Failed to re-encode response"
    end

    test "does not re-encode un-specified bodies" do
      body = "£éduff" <> <<163, 233, 100, 117, 102, 102>>
      requester = fn _url, _headers, _options ->
        {:ok, %HTTPoison.Response{
          body: body,
          headers: []
        }}
      end

      assert {:ok, %{body: ^body}} = HTTPClient.get(nil, [], requester: requester)
    end
  end

  # copy/paste above, but adjust it for the post/4 function. Or, if you
  # want to be creative, make a macro to generate these tests for you.
end
```

Cool. That's a lot of tests.

Let's make those tests pass:

```elixir
defmodule MyApp.HTTPClient do
  @moduledoc """
  A wrapper around HTTPoison that takes care of post-processing depending on the response, namely:
    1) decompress the response if gzipped
    2) re-encode the body into UTF-8 if ISO-8859-1
  """
  @default_getter &HTTPoison.get/3
  @default_poster &HTTPoison.post/4
  @default_options [timeout: 300_000, recv_timeout: 60_000]

  require Logger

  @doc """
  GET a URL with headers. Supported options:
    requester: fn(url, headers, request_options)
  """
  @spec get(String.t(), HTTPoison.headers(), list()) ::
    {:ok, HTTPoison.Response.t()} | {:error, HTTPoison.Error.t()}
  def get(url, headers, request_options \\ []) do
    opts = request_options ++ @default_options
    {get, opts} = Keyword.pop(opts, :requester, @default_getter)

    url
    |> get.(headers, opts)
    |> process_response
  end

  @doc """
  POST a URL with a body, headers. Supported options:
    requester: fn(url, body, headers, request_options)
  """
  @spec post(String.t(), HTTPoison.body(), HTTPoison.headers(), list()) ::
    {:ok, HTTPoison.Response.t()} | {:error, HTTPoison.Error.t()}
  def post(url, body, headers, request_options \\ []) do
    opts = request_options ++ @default_options
    {post, opts} = Keyword.pop(opts, :requester, @default_poster)

    url
    |> post.(body, headers, opts)
    |> process_response
  end

  defp process_response(response) do
    response
    |> decompress_response
    |> reencode_response_to_utf8
  end

  defp decompress_response({:error, response}), do: {:error, response}
  defp decompress_response({status, %{headers: headers, body: body} = response}) do
    try do
      decompressed_body =
        headers
        |> find_header("content-encoding")
        |> decompress_body(body)

      {status, %{response | body: decompressed_body}}

    rescue
      _ ->
        Logger.error("Failed to decompress response: #{inspect response}")
        {status, response}
    end
  end

  defp reencode_response_to_utf8({:error, response}), do: {:error, response}
  defp reencode_response_to_utf8({status, %{headers: headers, body: body} = response}) do
    try do
      reencoded_body =
        headers
        |> find_header("content-type")
        |> parse_charset()
        |> reencode_body(body)

      {status, %{response | body: reencoded_body}}

    rescue
      _ ->
        Logger.error("Failed to re-encode response: #{inspect response}")
        {status, response}
    end
  end

  defp find_header(headers, header_name) do
    Enum.find_value(
      headers,
      fn {name, value} ->
        name =~ ~r/#{header_name}/i && String.downcase(value)
      end
    )
  end

  # gzip's magic header is 0x1F 0x8B, with the 3rd byte specifying the compression method, 0x08
  # meaning "deflate". More info https://en.wikipedia.org/wiki/Gzip
  defp decompress_body(nil, body), do: body
  defp decompress_body("identity", body), do: body
  defp decompress_body("gzip", <<31, 139, 8, _::binary>> = body), do: :zlib.gunzip(body)
  defp decompress_body("gzip", body), do: body
  defp decompress_body("x-gzip", <<31, 139, 8, _::binary>> = body), do: :zlib.gunzip(body)
  defp decompress_body("x-gzip", body), do: body
  defp decompress_body("deflate", body), do: :zlib.unzip(body)
  defp decompress_body(other, body) do
    Logger.error("No support for decompression of body using '#{other}' algorithm.")
    body
  end

  defp parse_charset(nil), do: nil
  defp parse_charset(content_type) do
    with {:ok, _, _, %{"charset" => charset}} <- Plug.Conn.Utils.content_type(content_type) do
      cond do
        charset =~ ~r/utf-?8/ -> :utf8
        charset =~ ~r/iso-?8859-?1/ -> :latin1
        true -> charset
      end
    else
      _ -> nil
    end
  end

  # When the header isn't sent, the RFC spec says we should assume ISO-8859-1, but the default is
  # actually different per format, eg, XML should be assumed UTF-8. We're going to not re-encode
  # if it's not sent and assume UTF-8. This should be safe for most cases.
  defp reencode_body(nil, body), do: body
  defp reencode_body(:utf8, body), do: body
  defp reencode_body(:latin1, body) do
    case :unicode.characters_to_binary(body, :latin1, :utf8) do
      {:error, binary, rest} ->
        Logger.error("Failed to re-encode text. BODY: #{inspect binary} REST: #{inspect rest}")
        body

      {:incomplete, reencoded_text, rest} ->
        Logger.warn("Failed to re-encode entire text. Dropping characters: #{inspect rest}")
        reencoded_text

      reencoded_text ->
        reencoded_text
    end
  end
  defp reencode_body(other, body) do
    Logger.error("Need to implement re-encoding support for: #{other}")
    body
  end
end
```

## and... Done!

Hope this helps. Hit me up at [@bernheisel](https://twitter.com/bernheisel) if I
missed anything or you have another cool idea.

I'm not really interested in pulling this into a library, because that's exactly
what we don't need: yet another HTTP client. But, if you found yourself needing
to decompress responses with HTTPoison, then this will be a good start.

You'll notice that this doesn't implement all the calls (we're missing the ones
like `delete` and `head`), nor is it the smartest way to solve the problem. I'll
leave the gaps to inspire you.

## Or use [Tesla](https://github.com/teamon/tesla)
Tesla supports decompression out of the box; so if you started on that HTTP
client, you probably didn't have to worry about any of this :)


[Accept-Encoding]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Accept-Encoding
[Content-Encoding]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Encoding
[Content-Type]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Type
[brotli]: https://github.com/google/brotli
[HTTPoison]: https://github.com/edgurgel/httpoison
[Tesla]: https://github.com/teamon/tesla
[Mint]: https://github.com/ericmj/mint
[Gun]: https://github.com/ninenines/gun
[hackney]: https://github.com/benoitc/hackney
[hex.pm]: https://hex.pm/packages
[ExVCR]: https://github.com/parroty/exvcr
