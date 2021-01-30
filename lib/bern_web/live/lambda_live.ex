defmodule BernWeb.LambdaLive do
  use BernWeb, :live_view
  alias Bern.{LambdaTopic, LambdaTopicVote}

  @max_votes 3

  def mount(_params, %{"ip" => ip}, socket) do
    {:ok,
      socket
      |> assign(:ip, ip)
      |> assign(:topics, get_topics())
      |> assign(:my_votes, get_my_votes(ip))
      |> assign(:max_votes, @max_votes)
      |> assign(:notes, "")
      |> assign(:page_title, "Thinking Elixir LIVE at Lambda Days 2021")
      |> assign(:proposed_topic, LambdaTopic.changeset(%{}))
      |> track_attendees()
    }
  end

  defp get_topics(), do: LambdaTopic.all() |> Enum.filter(& &1.approved)

  def handle_event("validate", %{"lambda_topic" => %{"topic" => topic}}, socket) do
    {:noreply, assign(socket, :proposed_topic, LambdaTopic.changeset(%{topic: topic}))}
  end

  @thankyou """
  Thank you for proposing a topic! It's in the moderation queue now and will appear when approved.
  """ |> String.trim()
  def handle_event("submit_topic", %{"lambda_topic" => %{"topic" => topic}}, socket) do
    {:noreply, case LambdaTopic.create(topic) do
      :ok ->
        socket
        |> assign(:proposed_topic, LambdaTopic.changeset(%{}))
        |> put_flash(:info, @thankyou)
      {:error, changeset} ->
        assign(socket, :proposed_topic, changeset)
    end}
  end

  def handle_event("upvote", %{"id" => topic_id}, socket) do
    if length(socket.assigns.my_votes) < @max_votes do
      LambdaTopicVote.create(topic_id, socket.assigns.ip)
    end

    {:noreply, assign(socket, my_votes: get_my_votes(socket.assigns.ip))}
  end

  def handle_event("downvote", %{"id" => topic_id}, socket) do
    LambdaTopicVote.delete(topic_id, socket.assigns.ip)
    {:noreply, assign(socket, my_votes: get_my_votes(socket.assigns.ip))}
  end

  def handle_info([:topic, :new, _], socket), do: {:noreply, socket}
  def handle_info([:topic | _], socket) do
    {:noreply, assign(socket, topics: get_topics(), my_votes: get_my_votes(socket.assigns.ip))}
  end

  def handle_info(
      %{event: "presence_diff", payload: %{joins: joins, leaves: leaves}},
      %{assigns: %{attendees_count: count}} = socket
    ) do
    attendees = count + map_size(joins) - map_size(leaves)
    {:noreply, assign(socket, :attendees_count, attendees)}
  end

  defp get_my_votes(ip), do: LambdaTopicVote.for(ip: ip) |> Enum.map(& &1.topic_id)

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
