defmodule PathMapperWeb.MasterLive.LeftPanel.GroupSelectorTest do
  use PathMapperWeb.ConnCase
  import Phoenix.LiveViewTest

  setup %{conn: conn} do
    conn = get(conn, "/master")
    assert html_response(conn, 200)
    {:ok, view, html} = live(conn)

    {:ok, %{conn: conn, view: view, html: html}}
  end

  defp open(view) do
    view |> element("#group-selector-button") |> render_click()
    view
  end

  test "opens 'group selector' with a click", %{view: view, html: html} do
    assert !find_html_element(html, "#group-selector")
    assert find_html_element(render(open(view)), "#group-selector")
  end

  test "says so when no group is loaded", %{view: view} do
    assert find_html_element(render(open(view)), "#group-selector .empty-item")
  end

  test "shows the loaded group's name and id", %{view: view} do
    {:ok, _group} = load_group("tg0001-0000000001-group-1.zip")
    html = render(open(view))

    assert Floki.text(find_html_element(html, "#group-selector .loaded-item .item-id")) ==
             "tg0001-0000000001"
  end
end
