defmodule PathMapperWeb.MasterLive.LeftPanel.GroupSelectorTest do
  use PathMapperWeb.ConnCase
  import Phoenix.LiveViewTest

  alias PathMapper.Groups

  setup %{conn: conn} do
    conn = get(conn, "/master")
    assert html_response(conn, 200)
    {:ok, view, html} = live(conn)

    {:ok, %{conn: conn, view: view, html: html}}
  end

  test "opens 'group selector' with a click", %{view: view, html: html} do
    assert !find_html_element(html, "#group-selector")

    view
    |> element("#group-selector-button")
    |> render_click()

    assert find_html_element(render(view), "#group-selector")
  end

  test "selects 'group selector' item with a click", %{view: view} do
    first_group_name = List.first(Groups.get())

    view |> element("#group-selector-button") |> render_click()
    assert find_html_element(render(view), "#group-selector")

    view
    |> element("#group-selector button.item", first_group_name)
    |> render_click()

    assert find_html_element(render(view), "button.item.selected")
  end
end
