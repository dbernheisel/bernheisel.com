defmodule SEO.Breadcrumb.Item do
  @moduledoc ""

  defstruct [
    :name,
    :"@id"
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          "@id": String.t()
        }

  def render(%__MODULE__{} = item) do
    item |> Map.from_struct() |> SEO.json_library().encode!()
  end

  def new(item) when is_map(item) or is_list(item) do
    struct!(%__MODULE__{}, item)
  end
end
