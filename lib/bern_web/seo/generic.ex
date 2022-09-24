defmodule SEO.Generic do
  @moduledoc """
  This is generic SEO data for any search engine that isn't catered to any one feature.

  https://support.google.com/webmasters/answer/7451184?hl=en
  """

  defstruct [:site_description, :site_title]

  def new(overrides \\ []) do
    struct = %__MODULE__{}
    struct!(struct, Keyword.merge(Keyword.take(SEO.config(), Keyword.keys(struct)), overrides))
  end
end
