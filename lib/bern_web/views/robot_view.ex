defmodule BernWeb.RobotView do
  use BernWeb, :view

  def render("robots.txt", %{env: :prod}), do: ""
  def render("robots.txt", %{env: _}) do
    """
    User-agent: *
    Disallow: /
    """
  end
end
