defmodule PathMapperWeb.MasterLive.LeftPanel.AdventureSelectorTest do
  use PathMapperWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias PathMapper.Adventures

  test "opens 'adventure selector' with a click", %{conn: conn} do
    conn = get(conn, "/master")
    assert html_response(conn, 200)
    {:ok, view, html} = live(conn)

    assert !find_html_element(html, "#adventure-selector")

    view
    |> element("#adventure-selector-button")
    |> render_click()

    assert find_html_element(render(view), "#adventure-selector")
  end

  test "selects 'adventure selector' item with a click", %{conn: conn} do
    conn = get(conn, "/master")
    assert html_response(conn, 200)
    {:ok, view, _html} = live(conn)

    first_adventure_name = List.first(Adventures.get().list)

    view |> element("#adventure-selector-button") |> render_click()
    assert find_html_element(render(view), "#adventure-selector")

    view
    |> element("#adventure-selector button.item", first_adventure_name)
    |> render_click()

    assert find_html_element(render(view), "button.item.selected")
  end
end
