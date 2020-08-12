defmodule BernWeb.LinkHelpers do
  @doc """
  A shim for Phoenix.HTML.Link.link, but adding attributes for external URLs
  """
  def outbound_link(text, opts \\ [])
  def outbound_link(opts, do: contents) when is_list(opts) do
    outbound_link(contents, opts)
  end
  def outbound_link(text, opts) do
    Phoenix.HTML.Link.link(text, [rel: "nofollow noopener"] ++ opts)
  end

  @doc """
  A shim for Phoenix.HTML.Link.link, but adding a class if currently on the page
  """
  def active_link(conn, text, opts \\ [])

  def active_link(conn, opts, do: contents) when is_list(opts) do
    active_link(conn, contents, opts)
  end

  def active_link(conn, text, opts) do
    state =
      if String.starts_with?(Phoenix.Controller.current_path(conn), Keyword.fetch!(opts, :to)),
        do: :active,
        else: :inactive
    do_active_link(state, text, opts)
  end

  def do_active_link(state, text, opts) do
    {class, opts} = Keyword.pop(opts, :class)
    {inactive_class, opts} = Keyword.pop(opts, :inactive)
    {active_class, opts} = Keyword.pop(opts, :active)
    state_class = state == :inactive && inactive_class || active_class
    class = "#{class} #{state_class}"
    Phoenix.LiveView.Helpers.live_redirect(text, opts ++ [class: class])
  end

end
