defmodule PathMapperWeb.MasterLive.SceneSelectorTest do
  use PathMapperWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias PathMapper.Adventures

  test "opens and closes 'scene selector' with a click", %{conn: conn} do
    load_an_adventure()

    conn = get(conn, "/master")
    assert html_response(conn, 200)
    {:ok, view, html} = live(conn)

    assert !find_html_element(html, "#scene-selector")

    view |> element("#scene-selector-button") |> render_click()
    assert find_html_element(render(view), "#scene-selector")

    view |> element("#scene-selector-button") |> render_click()
    assert !find_html_element(render(view), "#scene-selector")
  end

  test "opens and closes 'scene selector' with a keystroke", %{conn: conn} do
    load_an_adventure()

    conn = get(conn, "/master")
    assert html_response(conn, 200)
    {:ok, view, html} = live(conn)

    assert !find_html_element(html, "#scene-selector")

    render_keydown(view, "navigate", %{"key" => "p"})
    render_keydown(view, "navigate", %{"key" => "s"})
    assert find_html_element(render(view), "#scene-selector")

    render_keydown(view, "navigate", %{"key" => "p"})
    render_keydown(view, "navigate", %{"key" => "s"})
    assert !find_html_element(render(view), "#scene-selector")
  end

  test "selects 'scene selector' item with a click", %{conn: conn} do
    load_an_adventure()

    conn = get(conn, "/master")
    assert html_response(conn, 200)
    {:ok, view, _html} = live(conn)

    first_scene_name = List.first(Adventures.get().loaded.scenes).name

    view |> element("#scene-selector-button") |> render_click()
    assert find_html_element(render(view), "#scene-selector")

    view |> element("#scene-selector button.item", first_scene_name) |> render_click()
    assert find_html_element(render(view), "button.item.selected")
  end

  test "selects 'scene selector' item with a keystroke", %{conn: conn} do
    conn = get(conn, "/master")
    assert html_response(conn, 200)
    {:ok, view, _html} = live(conn)

    view |> element("#scene-selector-button") |> render_click()
    assert find_html_element(render(view), "#scene-selector")

    render_keydown(view, "navigate", %{"key" => "l"})
    render_keydown(view, "navigate", %{"key" => "1"})

    assert find_html_element(render(view), "#scene-selector .item.selected")
  end

  def load_an_adventure do
    first_adventure_name = List.first(Adventures.get().list)
    {:ok, _adventure} = Adventures.load_adventure(first_adventure_name)
  end
end
