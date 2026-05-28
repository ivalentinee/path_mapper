defmodule PathMapper.Game.InitializeTest do
  use PathMapperWeb.ConnCase
  import Phoenix.LiveViewTest

  alias PathMapper.Adventures
  alias PathMapper.Game
  alias PathMapper.Groups

  setup %{conn: conn} do
    {:ok, adventure} = Adventures.load_adventure("adventure-1.zip")
    {:ok, _group} = Groups.load_group("group-1.zip")

    conn = get(conn, "/master")
    assert html_response(conn, 200)
    {:ok, view, _html} = live(conn)

    {:ok, %{view: view, adventure: adventure}}
  end

  test "adventure load eagerly initializes all scenes with tokens", %{
    view: view,
    adventure: adventure
  } do
    view |> element("#scene-selector-button") |> render_click()

    first_scene_def = Enum.at(adventure.scenes, 0)

    # Select scene 0 — should already have tokens from eager init
    view |> element("#scene-selector button.item", first_scene_def.name) |> render_click()

    game_state = Game.get_state()
    assert length(game_state.scene.tokens) === length(first_scene_def.place_tokens)
  end

  test "eagerly initialized tokens are placed at specified positions", %{
    view: view,
    adventure: adventure
  } do
    view |> element("#scene-selector-button") |> render_click()

    first_scene_def = Enum.at(adventure.scenes, 0)
    view |> element("#scene-selector button.item", first_scene_def.name) |> render_click()

    first_place_token = Enum.at(first_scene_def.place_tokens, 0)
    first_game_token = Enum.at(Game.get_state().scene.tokens, 0)

    assert first_game_token.x === first_place_token.x
    assert first_game_token.y === first_place_token.y
  end

  test "scene with no place_tokens initializes with empty tokens", %{
    view: view,
    adventure: adventure
  } do
    view |> element("#scene-selector-button") |> render_click()

    second_scene_def = Enum.at(adventure.scenes, 1)
    view |> element("#scene-selector button.item", second_scene_def.name) |> render_click()

    assert Game.get_state().scene.tokens === []
  end
end
