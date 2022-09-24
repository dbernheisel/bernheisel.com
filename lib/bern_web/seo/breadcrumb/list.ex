defmodule SEO.Breadcrumb.List do
  @moduledoc ""

  alias SEO.Breadcrumb.Item
  alias SEO.Breadcrumb.ListItem

  defstruct "@context": "https://schema.org",
            "@type": "BreadcrumbList",
            itemListElement: []

  @type t :: %__MODULE__{
          "@context": String.t(),
          "@type": String.t(),
          itemListElement: list(ListItem.t())
        }

  def render(%__MODULE__{} = item) do
    %{
      item
      | itemListElement:
          Enum.map(item.itemListElement, fn list_item ->
            %{Map.from_struct(list_item) | item: Map.from_struct(list_item.item)}
          end)
    }
    |> Map.from_struct()
    |> SEO.json_library().encode!()
  end

  def new(items) when is_list(items) do
    %__MODULE__{itemListElement: format_items(items)}
  end

  defp format_items(items) do
    Enum.with_index(items, fn item, i ->
      i = i + 1

      case item do
        %ListItem{position: pos} = list_item ->
          %{list_item | position: pos || i}

        %Item{} = item ->
          ListItem.new(item: item, position: i)

        attrs when is_list(attrs) or is_map(attrs) ->
          ListItem.new(
            item: Item.new(attrs),
            position: i
          )
      end
    end)
  end
end
