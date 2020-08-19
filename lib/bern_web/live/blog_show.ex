defmodule BernWeb.Live.BlogShow do
  use BernWeb, :live_view

  def mount(%{"id" => id}, _session, socket) do
    post = Bern.Blog.get_post_by_id!(id)

    relevant =
      post.tags
      |> Enum.shuffle()
      |> List.first()
      |> Bern.Blog.get_posts_by_tag!()
      |> Enum.reject(& &1.id == post.id)
      |> Enum.shuffle()
      |> Enum.take(2)

    socket = socket |> assign(:post, post) |> track_users()

    {:ok,
      socket
      |> assign(:live_seo, true)
      |> assign(:relevant_posts, relevant)
      |> assign(:page_title, post.title),
      temporary_assigns: [relevant_posts: [], post: nil]}
  end

  defp track_users(socket) do
    topic = "blogpost:#{socket.assigns.post.id}"
    readers = topic |> BernWeb.Presence.list() |> map_size()
    if connected?(socket) do
      BernWeb.Endpoint.subscribe(topic)
      BernWeb.Presence.track(self(), topic, socket.id, %{id: socket.id})
    end

    assign(socket, :readers, readers)
  end

  def handle_info(
      %{event: "presence_diff", payload: %{joins: joins, leaves: leaves}},
      %{assigns: %{readers: count}} = socket
    ) do
    readers = count + map_size(joins) - map_size(leaves)
    {:noreply, assign(socket, :readers, readers)}
  end
end
