defmodule BernWeb.SEO.Breadcrumbs do
  @moduledoc """
  This is SEO for Google to display breadcrumbs in the search results.
  This allows the search result to search as multiple links:

  - The blog index
  - The blog post itself

  https://developers.google.com/search/docs/data-types/breadcrumbs
  https://json-ld.org/

  tester: https://search.google.com/test/rich-results
  tester: https://search.google.com/structured-data/testing-tool
  """

  alias BernWeb.Router.Helpers, as: Routes

  defmodule BreadcrumbList do
    @derive Jason.Encoder
    defstruct [
      "@context": "https://schema.org",
      "@type": "BreadcrumbList",
      itemListElement: []
    ]
  end

  defmodule BreadcrumbItem do
    @derive Jason.Encoder
    defstruct [
      :position,
      :name,
      :item,
      "@context": "https://schema.org",
      "@type": "ListItem"
    ]
  end

  def build(conn, %Bern.Blog.Post{} = post) do
    %BreadcrumbList{
      itemListElement: [
        %BreadcrumbItem{
          position: 1,
          name: "Posts",
          item: Routes.blog_url(conn, :index)
        },
        %BreadcrumbItem{
          position: 2,
          name: post.title,
          item: Routes.blog_url(conn, :show, post.id)
        }
      ]
    }
  end
end
