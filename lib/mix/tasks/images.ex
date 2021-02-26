defmodule Mix.Tasks.Images do
  use Mix.Task

  @shortdoc "Generate Social Media images for blog posts"
  @impl Mix.Task
  def run(_) do
    Enum.each(Bern.Blog.all_posts(), fn post ->
      Mix.shell().info("Converting #{post.id}")
      System.cmd(File.cwd!() <> "/bin/make-post-image.sh", [post.id, post.title])
    end)
  end
end
