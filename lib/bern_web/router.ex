defmodule BernWeb.Router do
  use BernWeb, :router
  import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {BernWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :put_ip_into_session
  end

  pipeline :robots do
    plug :accepts, ["xml", "json", "webmanifest"]
  end

  scope "/", BernWeb, log: false do
    pipe_through [:robots]

    get "/sitemap.xml", SitemapController, :index
    get "/robots.txt", RobotController, :robots
    get "/rss.xml", RobotController, :rss
    get "/site.webmanifest", RobotController, :site_webmanifest
    get "/browserconfig.xml", RobotController, :browserconfig
  end

  scope "/", BernWeb do
    pipe_through :browser

    live "/", Live.Page, :show
    live "/blog", Live.BlogIndex, :index, as: :blog
    live "/blog/:id", Live.BlogShow, :show, as: :blog
    live "/about", Live.Page, :show, as: :about, session: %{"page" => "about"}
    live "/projects", Live.Page, :show, as: :projects, session: %{"page" => "projects"}
  end

  pipeline :lambda do
    plug :put_root_layout, "lambda.html"
  end

  scope "/", BernWeb do
    pipe_through [:browser, :lambda]

    live "/lambda2021", LambdaLive, :index, as: :lambda
  end

  scope "/admin", BernWeb.Admin, as: :admin do
    pipe_through [:browser, :check_auth, :lambda]
    live_dashboard "/dashboard", metrics: BernWeb.Telemetry

    live "/lambda2021", LambdaLive, :index, as: :lambda
  end

  def check_auth(conn, _opts) do
    with {user, pass} <- Plug.BasicAuth.parse_basic_auth(conn),
         true <- user == System.get_env("AUTH_USER", "admin"),
         true <- pass == System.get_env("AUTH_PASS", "admin") do
      conn
    else
      _ ->
        conn
        |> Plug.BasicAuth.request_basic_auth()
        |> halt()
    end
  end

  defp put_ip_into_session(conn, _opts) do
    Plug.Conn.put_session(conn, :ip, to_string(:inet_parse.ntoa(conn.remote_ip)))
  end

end
