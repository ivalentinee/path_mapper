defmodule PathMapper.Game.InitializeTest do
  use PathMapperWeb.ConnCase
  import Phoenix.LiveViewTest

  alias PathMapper.Game
  alias PathMapper.Groups

  setup %{conn: conn} do
    load_adventure("adventure-1.zip")
    {:ok, _group} = Groups.load_group("group-1.zip")

    conn = get(conn, "/master")
    assert html_response(conn, 200)
    {:ok, view, _html} = live(conn)

    {:ok, %{view: view}}
  end

  test "adventure load eagerly initializes all scenes with tokens", %{view: view} do
    view |> element("#scene-selector-button") |> render_click()

    # Select scene 0 — should already have tokens from eager init
    view |> element("#scene-selector button.item", "Scene 1") |> render_click()

    game_state = Game.get_state()
    assert length(game_state.scene.tokens) === 3
  end

  test "eagerly initialized tokens are placed at specified positions", %{view: view} do
    view |> element("#scene-selector-button") |> render_click()

    view |> element("#scene-selector button.item", "Scene 1") |> render_click()

    first_game_token = Enum.at(Game.get_state().scene.tokens, 0)

    assert first_game_token.x === 100
    assert first_game_token.y === 200
  end

  test "scene with no place_tokens initializes with empty tokens", %{view: view} do
    view |> element("#scene-selector-button") |> render_click()

    view |> element("#scene-selector button.item", "Scene 2") |> render_click()

    assert Game.get_state().scene.tokens === []
  end
end
