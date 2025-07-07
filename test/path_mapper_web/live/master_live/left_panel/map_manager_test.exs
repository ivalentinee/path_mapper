defmodule PathMapperWeb.MasterLive.LeftPanel.MapManagerTest do
  use PathMapperWeb.ConnCase
  import Phoenix.LiveViewTest

  alias PathMapper.Adventures
  alias PathMapper.Game
  alias PathMapper.Groups

  setup %{conn: conn} do
    {:ok, adventure} = Adventures.load_adventure("adventure-1.zip")
    {:ok, _group} = Groups.load_group("group-1.zip")
    :ok = Game.run_action([:scene, :select], 0)

    conn = get(conn, "/master")
    assert html_response(conn, 200)
    {:ok, view, html} = live(conn)

    {:ok, %{conn: conn, view: view, html: html, adventure: adventure}}
  end

  test "opens and closes 'map manager' with a click", %{view: view, html: html} do
    assert !find_html_element(html, "#map-manager")

    view |> element("#map-manager-button") |> render_click()
    assert find_html_element(render(view), "#map-manager")

    view |> element("#map-manager-button") |> render_click()
    assert !find_html_element(render(view), "#map-manager")
  end

  test "opens 'map manager' with a keystroke", %{view: view, html: html} do
    assert !find_html_element(html, "#map-manager")

    run_keystroke(view, ["p", "m"])
    assert find_html_element(render(view), "#map-manager")
  end

  test "shows/hides a layer with a click", %{view: view} do
    assert first_layer_state().show == true

    view |> element("#map-manager-button") |> render_click()

    view |> element("#layer-0 button.toggle-layer-show") |> render_click()
    assert first_layer_state().show == false

    view |> element("#layer-0 button.toggle-layer-show") |> render_click()
    assert first_layer_state().show == true
  end

  test "shows/hides a layer with a keystroke", %{view: view} do
    assert first_layer_state().show == true

    run_keystroke(view, ["p", "m", "1", "s"])
    assert first_layer_state().show == false

    run_keystroke(view, ["p", "m", "1", "s"])
    assert first_layer_state().show == true
  end

  test "dims/undims a layer with a click", %{view: view} do
    assert first_layer_state().light == "bright"

    view |> element("#map-manager-button") |> render_click()

    view |> element("#layer-0 button.toggle-layer-light") |> render_click()
    assert first_layer_state().light == "dim"

    view |> element("#layer-0 button.toggle-layer-light") |> render_click()
    assert first_layer_state().light == "bright"
  end

  test "dims/undims a layer with a keystroke", %{view: view} do
    assert first_layer_state().light == "bright"

    run_keystroke(view, ["p", "m", "1", "l"])
    assert first_layer_state().light == "dim"

    run_keystroke(view, ["p", "m", "1", "l"])
    assert first_layer_state().light == "bright"
  end

  test "highlights/hides a layer with a click", %{view: view} do
    assert first_layer_state().highlight == false

    view |> element("#map-manager-button") |> render_click()

    view |> element("#layer-0 button.toggle-layer-highlight") |> render_click()
    assert first_layer_state().highlight == true

    view |> element("#layer-0 button.toggle-layer-highlight") |> render_click()
    assert first_layer_state().highlight == false
  end

  test "highlights/hides a layer with a keystroke", %{view: view} do
    assert first_layer_state().highlight == false

    run_keystroke(view, ["p", "m", "1", "h"])
    assert first_layer_state().highlight == true

    run_keystroke(view, ["p", "m", "1", "h"])
    assert first_layer_state().highlight == false
  end

  test "hides/shows map grid with a click", %{view: view} do
    assert Game.get_state().scene.map.show_grid == true

    view |> element("#map-manager-button") |> render_click()
    view |> element("#toggle_grid") |> render_click()
    assert Game.get_state().scene.map.show_grid == false

    view |> element("#toggle_grid") |> render_click()
    assert Game.get_state().scene.map.show_grid == true
  end

  test "hides/shows map grid with a keystroke", %{view: view} do
    assert Game.get_state().scene.map.show_grid == true

    run_keystroke(view, ["p", "m", "g"])
    assert Game.get_state().scene.map.show_grid == false

    run_keystroke(view, ["p", "m", "g"])
    assert Game.get_state().scene.map.show_grid == true
  end

  def first_layer(adventure),
    do: adventure.scenes |> Enum.at(0) |> get_in([:map, :layers]) |> Enum.at(0)

  def first_layer_state, do: Game.get_state().scene.map.layers |> Enum.at(0)
end
