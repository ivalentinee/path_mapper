defmodule PathMapperWeb.MasterLive.LeftPanel.AdventureSelectorTest do
  use PathMapperWeb.ConnCase
  import Phoenix.LiveViewTest

  alias PathMapper.Adventures

  setup %{conn: conn} do
    conn = get(conn, "/master")
    assert html_response(conn, 200)
    {:ok, view, html} = live(conn)

    {:ok, %{conn: conn, view: view, html: html}}
  end

  test "opens 'adventure selector' with a click", %{view: view, html: html} do
    assert !find_html_element(html, "#adventure-selector")

    view
    |> element("#adventure-selector-button")
    |> render_click()

    assert find_html_element(render(view), "#adventure-selector")
  end

  test "selects 'adventure selector' item with a click", %{view: view} do
    first_adventure_name = List.first(Adventures.get())

    view |> element("#adventure-selector-button") |> render_click()
    assert find_html_element(render(view), "#adventure-selector")

    view
    |> element("#adventure-selector button.item", first_adventure_name)
    |> render_click()

    assert find_html_element(render(view), "button.item.selected")
  end

  test "loading malformed adventure shows error overlay", %{view: view} do
    view |> element("#adventure-selector-button") |> render_click()

    view
    |> element("#adventure-selector button.item", "bad-adventure.zip")
    |> render_click()

    html = render(view)
    assert find_html_element(html, ".load-errors-overlay")
    assert find_html_element(html, ".load-error-item")
  end

  test "dismiss button clears error overlay", %{view: view} do
    view |> element("#adventure-selector-button") |> render_click()
    view |> element("#adventure-selector button.item", "bad-adventure.zip") |> render_click()
    assert find_html_element(render(view), ".load-errors-overlay")

    view |> element(".load-errors-dismiss") |> render_click()
    refute find_html_element(render(view), ".load-errors-overlay")
  end

  test "reload button refreshes adventure list", %{view: view} do
    view |> element("#adventure-selector-button") |> render_click()

    view
    |> element("#adventure-selector button.sub-button", "Reload")
    |> render_click()

    html = render(view)
    assert find_html_element(html, "#adventure-selector")
    assert find_html_element(html, "#adventure-selector button.item")
  end
end
