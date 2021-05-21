defmodule BernWeb.SEO do
  @moduledoc "You know, juice."

  use BernWeb, :view
  alias BernWeb.SEO.{Generic, Breadcrumbs, OpenGraph}

  @default_assigns %{canonical_url: nil, site: %Generic{}, breadcrumbs: nil, og: nil}

  def meta(conn, BernWeb.Live.BlogShow, %{post: post}) do
    render(
      "meta.html",
      @default_assigns
      |> put_canonical(conn, post)
      |> put_opengraph_tags(conn, post)
      |> put_breadcrumbs(conn, post)
    )
  end

  def meta(conn, _view, _assigns),
    do: render("meta.html", @default_assigns |> put_canonical(conn, nil))

  def put_canonical(assigns, _conn, %{original_url: url}) when url not in ["", nil],
    do: Map.put(assigns, :canonical_url, url)

  def put_canonical(assigns, conn, _post),
    do: Map.put(assigns, :canonical_url, "https://bernheisel.com#{Phoenix.Controller.current_path(conn)}")

  def put_opengraph_tags(assigns, conn, event),
    do: Map.put(assigns, :og, OpenGraph.build(conn, event))

  def put_breadcrumbs(assigns, conn, event),
    do: Map.put(assigns, :breadcrumbs, Breadcrumbs.build(conn, event))
end
