defmodule PathMapperWeb.MasterLive.PanelSelectionTest do
  use PathMapperWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "opens and closes 'adventure selector' with a click", %{conn: conn} do
    conn = get(conn, "/master")
    assert html_response(conn, 200)
    {:ok, view, html} = live(conn)

    assert !find_html_element(html, "#adventure-selector")

    view
    |> element("#adventure-selector-button")
    |> render_click()

    assert find_html_element(render(view), "#adventure-selector")
  end
end
