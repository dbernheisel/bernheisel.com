defprotocol SEO.Build do
  @spec to_breadcrumb_list(term) :: SEO.Breadcrumb.List.t()
  def to_breadcrumb_list(term)

  @spec to_open_graph(term) :: SEO.OpenGraph.t()
  def to_open_graph(term)
end

defimpl SEO.Build, for: Map do
  def to_breadcrumb_list(item) do
    SEO.Breadcrumb.new(item)
  end

  def to_open_graph(item) do
    SEO.OpenGraph.new(item)
  end
end
