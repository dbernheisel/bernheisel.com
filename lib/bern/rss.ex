defmodule Bern.Rss do
  @moduledoc """

  """

  def generate() do
    Bern.Blog.all_posts()
    |> Stream.map(&to_item/1)
  end

  def to_item(post) do
    post
  end
end
