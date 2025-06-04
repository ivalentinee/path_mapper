defmodule PathMapperWeb.TestHelpers do
  def find_html_element(html, selector) when is_binary(html) and is_binary(selector) do
    {:ok, document} = Floki.parse_document(html)
    found_elements = Floki.find(document, selector)
    List.first(found_elements)
  end
end
