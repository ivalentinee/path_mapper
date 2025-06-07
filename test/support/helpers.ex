defmodule PathMapperWeb.TestHelpers do
  alias Phoenix.LiveViewTest

  def find_html_element(html, selector) when is_binary(html) and is_binary(selector) do
    {:ok, document} = Floki.parse_document(html)
    found_elements = Floki.find(document, selector)
    List.first(found_elements)
  end

  def run_keystroke(view, keystroke) when is_list(keystroke) do
    Enum.map(keystroke, fn key ->
      LiveViewTest.render_keydown(view, "navigate", %{"key" => key})
    end)
  end
end
