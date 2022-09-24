defmodule SEO.Breadcrumb.ListItem do
  @moduledoc ""

  defstruct [
    :position,
    :item,
    "@context": "https://schema.org",
    "@type": "ListItem"
  ]

  @type t :: %__MODULE__{
          position: pos_integer(),
          "@context": String.t(),
          "@type": String.t(),
          item: SEO.Breadcrumb.Item.t()
        }

  def render(%__MODULE__{} = list_item) do
    list_item |> Map.from_struct() |> SEO.json_library().encode!()
  end

  def new(list_item) when is_map(list_item) or is_list(list_item) do
    struct!(%__MODULE__{}, list_item)
  end
end
