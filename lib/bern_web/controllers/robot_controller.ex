defmodule BernWeb.RobotController do
  use Phoenix.Controller,
    formats: ~w[json txt xml webmanifest]a

  use BernWeb, :verified_routes

  import Plug.Conn

  alias Bern.Blog
  alias BernWeb.RSS
  alias BernWeb.RobotXML
  alias BernWeb.SEO

  plug :accepts, ~w[json txt xml webmanifest]
  plug :put_layout, false

  def robots(conn, _params) do
    text(conn, """
    User-agent: *
    Disallow: /admin
    """)
  end

  @icon_sizes [
    [size: "36x36", density: "0.75"],
    [size: "48x48", density: "1.0"],
    [size: "72x72", density: "1.5"],
    [size: "144x144", density: "2.0"],
    [size: "192x192", density: "3.0"]
  ]

  def site_webmanifest(conn, _params) do
    json(conn, %{
      name: "bernheisel.com",
      short_name: "Bernheisel",
      icons:
        for [size: size, density: density] <- @icon_sizes do
          %{
            src: static_url(conn, "/images/android-chrome-#{size}.png"),
            sizes: size,
            density: density,
            type: "image/png"
          }
        end,
      theme_color: "#663399",
      display: "minimal-ui",
      background_color: "#ffffff"
    })
  end

  def rss(conn, _params) do
    generic = SEO.site_config(conn)

    rss =
      RSS.generate(%RSS{
        title: generic.title,
        author: "David Bernheisel",
        description: generic.description,
        posts: Blog.published_posts()
      })

    conn
    |> put_resp_content_type("application/xml")
    |> resp(200, rss)
  end

  def browserconfig(conn, _params) do
    render_xml(conn, "browserconfig.xml", conn: conn, posts: Blog.published_posts())
  end

  def sitemap(conn, _params) do
    render_xml(conn, "sitemap.xml", conn: conn, posts: Blog.published_posts())
  end

  def render_xml(conn, template, assigns) do
    conn
    |> put_resp_content_type("application/xml")
    |> put_view(RobotXML)
    |> render(template, assigns)
  end
end
