defmodule BernWeb.BlogLive do
  use BernWeb, :live_view

  # Show
  def mount(%{"id" => id, "preview" => "true"}, _session, socket) do
    {:ok, id |> Bern.Blog.get_post_preview_by_id!() |> show(socket),
     temporary_assigns: [relevant_posts: [], post: nil]}
  end

  def mount(%{"id" => id}, _session, socket) do
    {:ok, id |> Bern.Blog.get_post_by_id!() |> show(socket),
     temporary_assigns: [relevant_posts: [], post: nil]}
  end

  # Index
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:posts, Bern.Blog.published_posts())
     |> assign(:page_title, "Blog"), temporary_assigns: [posts: []]}
  end

  # Show
  def handle_params(%{"id" => id, "preview" => "true"}, _session, socket) do
    {:noreply, id |> Bern.Blog.get_post_preview_by_id!() |> show(socket)}
  end

  def handle_params(%{"id" => id}, _session, socket) do
    {:noreply, id |> Bern.Blog.get_post_by_id!() |> show(socket)}
  end

  # Index
  def handle_params(_params, _session, socket) do
    {:noreply, socket}
  end

  def show(post, socket) do
    socket
    |> assign(:post, post)
    |> maybe_assign_canonical_url(post)
    |> track_readers(post)
    |> assign(:relevant_posts, relevant_posts(post))
    |> assign(:breadcrumbs, BernWeb.SEO.Breadcrumbs.build(post))
    |> assign(:og, BernWeb.SEO.OpenGraph.build(post))
    |> assign(:page_title, post.title)
  end

  defp maybe_assign_canonical_url(socket, %{canonical_url: url}) when url not in ["", nil] do
    assign(socket, :canonical_url, url)
  end

  defp maybe_assign_canonical_url(socket, _post), do: socket

  defp relevant_posts(post) do
    post.tags
    |> Enum.shuffle()
    |> List.first()
    |> Bern.Blog.get_posts_by_tag!()
    |> Enum.reject(&(&1.id == post.id || !&1.published))
    |> Enum.shuffle()
    |> Enum.take(2)
  end

  defp track_readers(socket, post) do
    topic = "blogpost:#{post.id}"
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
