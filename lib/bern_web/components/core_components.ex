defmodule BernWeb.CoreComponents do
  use Phoenix.Component

  @doc """
  A shim for Phoenix.HTML.Link.link, but adding attributes for external URLs
  """
  attr :to, :string, required: true
  slot :inner_block, required: true
  attr :rest, :global

  def outbound_link(assigns) do
    ~H"""
    <.link href={@to} {@rest} rel="nofollow noopener"><%= render_slot(@inner_block) %></.link>
    """
  end
end
