defmodule BernWeb.BlogLive do
  use BernWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket, temporary_assigns: [{SEO.key(), nil}, posts: [], relevant_posts: [], post: nil]}
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
    {:noreply,
     socket
     |> assign(:posts, Bern.Blog.published_posts())
     |> assign(:page_title, "Blog")}
  end

  def render(%{live_action: :show} = assigns) do
    ~H"""
    <.link
      patch={~p"/blog"}
      class="inline-flex items-center px-2 py-1 border border-transparent shadow-sm text-sm leading-4 font-medium rounded-md dark:bg-gray-700 dark:text-gray-300 text-gray-700 bg-gray-300 dark:hover:bg-gray-600 hover:bg-gray-400 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gray-500 print:hidden"
    >
      <svg class="-ml-0.5 mr-2 w-5 h-5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16l-4-4m0 0l4-4m-4 4h18" />
      </svg>
      all posts
    </.link>
    <article id={"post-#{@post.id}"}>
      <h1 class="font-extrabold text-4xl leading-relaxed">
        <%= @post.title %>
      </h1>

      <p>
        Published on <%= Date.to_iso8601(@post.date) %>
      </p>

      <div class="flex flex-wrap mt-2 space-x-4 mb-12 text-sm">
        <%= if @post.canonical_url do %>
          <div>
            <.outbound_link class="border-b-2 hover:border-accent-500 transition-colors duration-150 ease-in-out" to={@post.canonical_url}>Original Publishing</.outbound_link>
          </div>
        <% end %>
        <div>
          <%= @post.reading_time %>m read
        </div>
        <%= if @readers > 1 do %>
          <div>
            <%= @readers %> current readers
          </div>
        <% end %>
        <%= if Enum.any?(@post.tags) do %>
          <div>
            <%= Enum.join(@post.tags, ", ") %>
          </div>
        <% end %>
      </div>

      <div id={"post-content-#{@post.id}"} phx-hook="Highlight" class="mb-6 prose dark:prose-invert print:prose-print lg:prose-xl" phx-update="ignore">
        <%= raw(@post.body) %>
      </div>
    </article>

    <div class="block print:hidden">
      <hr class="my-8" />
      <h3 class="text-lg font-bold">What do you think of what I said?</h3>
      <div class="mt-4 mb-10">
        Share with me your thoughts. You can
        <.outbound_link class="link" to="https://twitter.com/bernheisel">tweet me at @bernheisel</.outbound_link>
        <%= if @post.discussion_url do %>
          or
          <.outbound_link class="link" to={@post.discussion_url}>leave a comment at GitHub</.outbound_link>
        <% end %>
        .
      </div>
    </div>

    <%= if Enum.any?(@relevant_posts) do %>
      <div class="block print:hidden">
        <hr class="my-8" />

        <h3 class="text-lg leading-10 font-medium">Other articles that may interest you</h3>

        <div class="flex flex-wrap mt-4 mb-10 justify-between">
          <div :for={relevant_post <- @relevant_posts} class="w-full p-2 lg:w-1/2">
            <.link
              patch={~p"/blog/#{relevant_post}"}
              class="text-white no-underline px-3 py-2 dark:bg-gray-600 dark:border-gray-500 dark:hover:bg-gray-500 dark:hover:border-gray-400 bg-brand-500 border-brand-600 rounded shadow duration-100 ease-in-out transition-colors inline-flex items-center flex-1 hover:bg-brand-600 hover:border-brand-700 dark:button-dark"
            >
              <svg viewBox="0 0 20 20" fill="currentColor" class="mr-2 fill-current w-6 h-6">
                <path
                  fill-rule="evenodd"
                  d="M12.586 4.586a2 2 0 112.828 2.828l-3 3a2 2 0 01-2.828 0 1 1 0 00-1.414 1.414 4 4 0 005.656 0l3-3a4 4 0 00-5.656-5.656l-1.5 1.5a1 1 0 101.414 1.414l1.5-1.5zm-5 5a2 2 0 012.828 0 1 1 0 101.414-1.414 4 4 0 00-5.656 0l-3 3a4 4 0 105.656 5.656l1.5-1.5a1 1 0 10-1.414-1.414l-1.5 1.5a2 2 0 11-2.828-2.828l3-3z"
                  clip-rule="evenodd"
                >
                </path>
              </svg>
              <span><%= relevant_post.title %></span>
            </.link>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  def render(%{live_action: :index} = assigns) do
    ~H"""
    <%= for post <- @posts do %>
      <div id={"post-#{post.id}"} class="border-b-2 border-dotted border-gray-300 last:border-b-0 mb-8 pb-2">
        <h1 class="text-3xl leading-relaxed mb-4 font-semibold">
          <.link patch={~p"/blog/#{post}"} class="transition-colors duration-150 border-transparent border-b-4 focus:border-brand-500 hover:border-accent-500"><%= post.title %></.link>
        </h1>

        <p class="leading-normal">
          <%= raw(post.description) %>
        </p>

        <p class="my-4">
          <.link patch={~p"/blog/#{post}"} class="transition-colors duration-150 border-b-4 focus:border-brand-500 hover:border-accent-500">Read more...</.link>
        </p>

        <div class="flex space-x-2 mt-6 text-xs">
          <div><%= Date.to_iso8601(post.date) %></div>
          <%= if post.canonical_url do %>
            <div>
              <.outbound_link style="border-bottom-width: 1px" class="hover:border-accent-500 transition-colors duration-150 ease-in-out" to={post.canonical_url}>Original Publishing</.outbound_link>
            </div>
          <% end %>
          <div>
            <%= post.reading_time %>m read
          </div>
          <%= if Enum.any?(post.tags) do %>
            <div>
              <%= Enum.join(post.tags, ", ") %>
            </div>
          <% end %>
        </div>
      </div>
    <% end %>
    """
  end

  def show(post, socket) do
    socket
    |> assign(:post, post)
    |> track_readers(post)
    |> assign(:relevant_posts, relevant_posts(post))
    |> SEO.assign(post)
  end

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
