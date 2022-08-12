defmodule Mix.Tasks.ValidateUrls do
  unless Mix.env() == :prod do
    use Mix.Task

    @shortdoc "Verify that URLs are live"
    def run(_opts) do
      Application.ensure_started(:telemetry)
      urls_table = :ets.new(:external_links, [:set])

      Finch.start_link(
        name: UrlValidator,
        pools: %{
          default: [size: 10, count: 1]
        }
      )

      Bern.Blog.all_posts()
      |> Stream.each(&get_external_urls(&1, urls_table))
      |> Stream.run()

      Stream.resource(
        fn -> :ets.first(urls_table) end,
        fn
          :"$end_of_table" ->
            {:halt, nil}

          previous_key ->
            next_key = :ets.next(urls_table, previous_key)

            case check_live(previous_key, urls_table) do
              {:ok, _url} -> {[], next_key}
              error -> {[error], next_key}
            end
        end,
        fn _ -> :ok end
      )
      |> Enum.to_list()
      |> case do
        [] ->
          exit(:normal)

        results ->
          results
          |> Enum.group_by(
            fn {status, _val} -> status end,
            fn {_, val} -> val end
          )
          |> inspect(
            pretty: true,
            limit: :infinity,
            printable_limit: :infinity
          )
          |> Mix.Shell.IO.error()

          exit({:shutdown, 1})
      end
    end

    defp check_live(:"$end_of_table", _urls_table), do: nil

    defp check_live(url, urls_table) do
      Mix.Shell.IO.info("Checking #{url}")
      [{_, blog_ids}] = :ets.lookup(urls_table, url)

      :get
      |> Finch.build(url)
      |> Finch.request(UrlValidator)
      |> case do
        {:ok, %{status: status}} when status >= 200 and status < 300 ->
          {:ok, url}

        {:ok, %{status: status, headers: headers}} when status in 301..302 or status in 307..308 ->
          to = Enum.find_value(headers, fn {name, value} -> name == "location" && value end)
          {:redirect, [from: url, to: to, posts: blog_ids]}

        {:ok, %{status: status}} ->
          {:error, [url: url, status: status, posts: blog_ids]}

        {:error, %{reason: :timeout}} ->
          {:timeout, [url: url, posts: blog_ids]}

        {:error, %{reason: {_, :enhance_your_calm, _}}} ->
          Mix.Shell.IO.info("Rate-limited... #{url}")
          Process.sleep(5000)
          check_live(url, urls_table)

        {:error, %{reason: reason}} ->
          {:error, [url: url, reason: reason, posts: blog_ids]}
      end
    end

    @ignore ["https://twitter.com", "https://youtu.be", "#", "https://www.linode.com/?r="]
    defp get_external_urls(%{id: id, body: body}, table_pid) do
      body
      |> Floki.parse_fragment!()
      |> Floki.find("a[href]")
      |> Floki.attribute("href")
      |> Enum.reject(&String.starts_with?(&1, @ignore))
      |> Enum.uniq()
      |> Enum.each(fn url ->
        case :ets.lookup(table_pid, url) do
          [] ->
            :ets.insert(table_pid, {url, [id]})

          [{url, ids}] ->
            :ets.insert(table_pid, {url, [id | ids]})
        end
      end)
    end
  end
end
