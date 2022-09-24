defmodule SEO.Utils do
  def format_date(date), do: Date.to_iso8601(date)

  def truncate(text, length \\ 200) do
    if String.length(text) <= length do
      text
    else
      String.slice(text, 0..length)
    end
    |> String.trim()
  end
end
