defmodule BernWeb.PageLive do
  use BernWeb, :live_view

  @impl true
  def mount(_params, _session, %{assigns: %{live_action: :home}} = socket) do
    {:ok, redirect(socket, to: ~p"/blog")}
  end

  def mount(_params, _session, %{assigns: %{live_action: :projects}} = socket) do
    {:ok, assign(socket, :page_title, "Projects")}
  end

  @impl true
  def render(%{live_action: :home} = assigns), do: ~H""

  def render(%{live_action: :projects} = assigns) do
    ~H"""
    <div class="prose dark:prose-invert lg:prose-xl">
      <article>
        <h2>Ecto In Production</h2>
        <div class="space-x-4">
          <.outbound_link to="https://www.ectoinproduction.com">ectoinproduction.com</.outbound_link>
        </div>
        <p>Education platform for Elixir and Ecto users. Guides and recipes for the common developer for Elixir apps using Ecto in production.</p>
        <img src={~p"/images/ecto-in-production.png"} class="p-3 rounded-lg" alt="Ecto in Production" />
      </article>

      <article>
        <h2>Phoenix SEO</h2>
        <div class="space-x-4">
          <.outbound_link to="https://github.com/dbernheisel/phoenix_seo">GitHub</.outbound_link>
          <.outbound_link to="https://hex.pm/packages/phoenix_seo">Published on hex.pm</.outbound_link>
        </div>
        <p>SEO Library to help Phoenix users optimize their site for search engines</p>

        <img src="https://github.com/dbernheisel/phoenix_seo/raw/main/priv/logo.png" class="p-3 rounded-lg" alt="Phoenix
        SEO" />
      </article>

      <article>
        <h2>DateTimeParser</h2>
        <div class="space-x-4">
          <.outbound_link to="https://github.com/dbernheisel/date_time_parser">GitHub</.outbound_link>
          <.outbound_link to="https://hex.pm/packages/date_time_parser">Published on hex.pm</.outbound_link>
        </div>
        <p>Major functions:</p>
        <ul>
          <li>Parse an Elixir DateTime, NaiveDateTime, Date, or Time from a string</li>
          <li>Tokenizes found parts of the datetime through binary matching</li>
          <li>Supports major ISO formats</li>
          <li>Supports arbitrary formats, eg "Saturday, Jan-34-04"</li>
        </ul>
        <img src={~p"/images/date_time_parser_sample.png"} class="p-3 rounded-lg bg-gray-900" alt="DateTimeParser sample usage screenshot" />
      </article>

      <article>
        <h2>Elixir Stream</h2>
        <div class="space-x-4">
          <.outbound_link to="https://github.com/zestcreative/elixirstream">GitHub</.outbound_link>
          <.outbound_link to="https://elixirstream.dev">Visit</.outbound_link>
        </div>
        <p>Major functions:</p>
        <ul>
          <li>LiveView-powered HTTP Sink. Echo out to screen HTTP requests to a specified URL</li>
          <li>
            LiveView-powered Regex visualizer.
            <ul>
              <li>See the raw result and the visualized result</li>
              <li>You can permalink regexes to share with others</li>
              <li>Cheatsheet and recipes</li>
            </ul>
          </li>
          <li>
            LiveView-powered Generater differ.
            <ul>
              <li>Stream the git diff between different versions or different flags provided to generators</li>
              <li>If the diff isn't already calculated, then queue the diff in a worker queue</li>
              <li>When working the diff, stream the console output to the user waiting for the diff</li>
            </ul>
          </li>
        </ul>
        <img src={~p"/images/utilities_sample.png"} class="p-3 rounded-lg bg-gray-100" alt="Elixir Utilities sample screenshot" />
      </article>

      <article>
        <h2>NewTab Notes - Chrome Extension</h2>
        <div class="space-x-4">
          <.outbound_link to="https://github.com/dbernheisel/MarkdownTab">GitHub</.outbound_link>
          <.outbound_link to="https://chrome.google.com/webstore/detail/newtab-notes/kfbhbipgippofpifimbcnbafehjndccn">Published on the Chrome Web Store</.outbound_link>
        </div>
        <p>Major functions:</p>
        <ul>
          <li>Replace the Chrome New Tab with a markdown page.</li>
          <li>Customize the look of what's rendered.</li>
          <li>Built with VueJS and Tailwind CSS</li>
          <li>Built purely for my own use.</li>
        </ul>
        <img src={~p"/images/markdowntab_sample.png"} class="p-3 rounded-lg bg-gray-100" alt="NewTab Notes sample screenshot" />
      </article>
    </div>
    """
  end
end
