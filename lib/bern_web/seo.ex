defmodule SEO do
  @moduledoc "internet juice."

  def config, do: Application.get_all_env(:seo)

  def json_library, do: Application.get_env(:seo, :json_library, Jason)
end
