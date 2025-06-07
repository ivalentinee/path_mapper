defmodule PathMapperWeb.MasterLive.LeftPanel.SceneSelectorTest do
  use PathMapperWeb.ConnCase
  import Phoenix.LiveViewTest

  alias PathMapper.Adventures

  setup %{conn: conn} do
    {:ok, _adventure_name} = load_an_adventure()

    conn = get(conn, "/master")
    assert html_response(conn, 200)
    {:ok, view, html} = live(conn)

    {:ok, %{conn: conn, view: view, html: html}}
  end

  test "opens and closes 'scene selector' with a click", %{view: view, html: html} do
    assert !find_html_element(html, "#scene-selector")

    view |> element("#scene-selector-button") |> render_click()
    assert find_html_element(render(view), "#scene-selector")

    view |> element("#scene-selector-button") |> render_click()
    assert !find_html_element(render(view), "#scene-selector")
  end

  test "opens 'scene selector' with a keystroke", %{view: view, html: html} do
    assert !find_html_element(html, "#scene-selector")

    render_keydown(view, "navigate", %{"key" => "p"})
    render_keydown(view, "navigate", %{"key" => "s"})
    assert find_html_element(render(view), "#scene-selector")
  end

  test "selects 'scene selector' item with a click", %{view: view} do
    first_scene_name = List.first(Adventures.get().loaded.scenes).name

    view |> element("#scene-selector-button") |> render_click()
    assert find_html_element(render(view), "#scene-selector")

    view |> element("#scene-selector button.item", first_scene_name) |> render_click()
    assert find_html_element(render(view), "button.item.selected")
  end

  test "selects 'scene selector' item with a keystroke", %{view: view} do
    render_keydown(view, "navigate", %{"key" => "p"})
    render_keydown(view, "navigate", %{"key" => "s"})
    render_keydown(view, "navigate", %{"key" => "1"})

    assert find_html_element(render(view), "#scene-selector .item.selected")
  end

  def load_an_adventure do
    first_adventure_name = List.first(Adventures.get().list)
    Adventures.load_adventure(first_adventure_name)
  end
end
