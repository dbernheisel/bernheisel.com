defmodule Bern.Blog do
  @moduledoc """
  """

  use NimblePublisher,
    build: Bern.Blog.Post,
    from: "posts/**/*.md",
    as: :posts,
    highlighters: [:makeup_elixir]

  defmodule NotFoundError do
    defexception [:message, plug_status: 404]
  end

  # The @posts variable is first defined by NimblePublisher.
  # Let's further modify it by sorting all posts by descending date.
  @published_posts @posts |> Enum.sort_by(& &1.date, {:desc, Date}) |> Enum.filter(& &1.published)
  @all_posts Enum.sort_by(@posts, & &1.date, {:desc, Date})

  # Let's also get all tags
  @tags @posts |> Enum.flat_map(& &1.tags) |> Enum.uniq() |> Enum.sort()

  # And finally export them
  def all_posts, do: @all_posts
  def published_posts, do: @published_posts
  def all_tags, do: @tags

  def get_post_by_id!(id) do
    Enum.find(published_posts(), &(&1.id == id)) ||
      raise NotFoundError, "post with id=#{id} not found"
  end

  def get_post_preview_by_id!(id) do
    Enum.find(all_posts(), &(&1.id == id)) ||
      raise NotFoundError, "post with id=#{id} not found"
  end

  def get_posts_by_tag!(tag) do
    case Enum.filter(all_posts(), &(tag in &1.tags)) do
      [] -> raise NotFoundError, "posts with tag=#{tag} not found"
      posts -> posts
    end
  end
end

