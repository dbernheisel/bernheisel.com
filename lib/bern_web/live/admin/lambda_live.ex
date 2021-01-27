defmodule BernWeb.Admin.LambdaLive do
  use BernWeb, :live_view
  alias Bern.{LambdaTopic, LambdaTopicVote}

  def mount(_params, %{"ip" => ip}, socket) do
    {:ok,
      socket
      |> assign(:ip, ip)
      |> assign(:topics, get_topics())
      |> assign(:notes, nil)
      |> assign(:notes_version, "1")
      |> assign(:page_title, "Admin - Thinking |> Elixir LIVE at Lambda Days 2021")
      |> track_attendees()
    }
  end

  @impl Phoenix.LiveComponent
  def handle_event("editor-update", content, socket) do
    {:noreply, assign(socket, :notes, content)}
  end

  def handle_event("approve", %{"id" => topic_id}, socket) do
    LambdaTopic.approve(topic_id)
    {:noreply, socket}
  end

  def handle_event("covered", %{"id" => topic_id}, socket) do
    LambdaTopic.cover(topic_id)
    {:noreply, socket}
  end

  def handle_event("trash", %{"id" => topic_id}, socket) do
    LambdaTopic.trash(topic_id)
    {:noreply, socket}
  end

  defp get_topics(), do: LambdaTopic.all()

  def handle_info([:topic | _], socket) do
    {:noreply, assign(socket, topics: get_topics())}
  end

  def handle_info(
      %{event: "presence_diff", payload: %{joins: joins, leaves: leaves}},
      %{assigns: %{attendees_count: count}} = socket
    ) do
    attendees = count + map_size(joins) - map_size(leaves)
    {:noreply, assign(socket, :attendees_count, attendees)}
  end

  defp track_attendees(socket) do
    topic = "lambda"
    attendees_count = topic |> BernWeb.Presence.list() |> map_size()
    if connected?(socket) do
      BernWeb.Endpoint.subscribe(topic)
      BernWeb.Presence.track(self(), topic, socket.assigns.ip, %{
        online_at: inspect(System.system_time(:second))
      })
    end

    assign(socket, :attendees_count, attendees_count)
  end
end
