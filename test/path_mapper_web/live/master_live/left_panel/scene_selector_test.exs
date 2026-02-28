defmodule PathMapperWeb.MasterLive.LeftPanel.SceneSelectorTest do
  use PathMapperWeb.ConnCase
  import Phoenix.LiveViewTest

  alias PathMapper.Adventures
  alias PathMapper.Game
  alias PathMapper.Groups

  setup %{conn: conn} do
    {:ok, _adventure_name} = Adventures.load_adventure("adventure-1.zip")
    {:ok, _group} = Groups.load_group("group-1.zip")

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

  test "selects 'scene selector' item with a click", %{view: view} do
    {:ok, %{scenes: [%{name: first_scene_name} | _rest]}} = Adventures.get_loaded()

    view |> element("#scene-selector-button") |> render_click()
    assert find_html_element(render(view), "#scene-selector")

    view |> element("#scene-selector button.item", first_scene_name) |> render_click()
    assert find_html_element(render(view), "button.item.selected")

    assert Enum.count(Game.get_state().scene.tokens) === 3
    first_token = Enum.at(Game.get_state().scene.tokens, 0)
    assert first_token.x == 10
    assert first_token.y == 20
    assert first_token.state == "unconscious"
  end

  test "unsets scene with a click", %{view: view} do
    find_html_element(render(view), "#scene-selector .item.selected")

    view |> element("#scene-selector-button") |> render_click()
    view |> element("#unset_scene") |> render_click()
    assert !find_html_element(render(view), "#scene-selector .item.selected")
  end
end
