defmodule BernWeb.ErrorHTMLTest do
  use BernWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template

  test "renders 404.html", %{conn: conn} do
    assert render_to_string(BernWeb.ErrorHTML, "404", "html", conn: conn) =~ "404 Not found"
  end

  test "renders 500.html", %{conn: conn} do
    assert render_to_string(BernWeb.ErrorHTML, "500", "html", conn: conn) =~ "500 Uhoh"
  end
end
