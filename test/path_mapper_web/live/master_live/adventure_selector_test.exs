defmodule PathMapperWeb.MasterLive.PanelSelectionTest do
  use PathMapperWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias PathMapper.Adventures

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

  test "opens and closes 'adventure selector' with a keystroke", %{conn: conn} do
    conn = get(conn, "/master")
    assert html_response(conn, 200)
    {:ok, view, html} = live(conn)

    assert !find_html_element(html, "#adventure-selector")

    render_keydown(view, "navigate", %{"key" => "p"})
    render_keydown(view, "navigate", %{"key" => "a"})

    assert find_html_element(render(view), "#adventure-selector")
  end

  test "selects 'adventure selector' item with a click", %{conn: conn} do
    conn = get(conn, "/master")
    assert html_response(conn, 200)
    {:ok, view, _html} = live(conn)

    first_adventure_name = List.first(Adventures.get_adventures().list)

    view |> element("#adventure-selector-button") |> render_click()
    assert find_html_element(render(view), "#adventure-selector")

    view
    |> element("#adventure-selector button.item", first_adventure_name)
    |> render_click()

    assert find_html_element(render(view), "button.item.selected")
  end

  test "selects 'adventure selector' item with a keystroke", %{conn: conn} do
    conn = get(conn, "/master")
    assert html_response(conn, 200)
    {:ok, view, _html} = live(conn)

    view |> element("#adventure-selector-button") |> render_click()
    assert find_html_element(render(view), "#adventure-selector")

    render_keydown(view, "navigate", %{"key" => "l"})
    render_keydown(view, "navigate", %{"key" => "1"})

    assert find_html_element(render(view), "#adventure-selector .item.selected")
  end
end
