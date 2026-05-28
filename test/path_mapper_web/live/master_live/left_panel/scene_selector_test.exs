defmodule PathMapperWeb.MasterLive.LeftPanel.SceneSelectorTest do
  use PathMapperWeb.ConnCase
  import Phoenix.LiveViewTest

  alias PathMapper.Adventures
  alias PathMapper.Game
  alias PathMapper.Groups

  setup %{conn: conn} do
    load_adventure("adventure-1.zip")
    {:ok, _group} = Groups.load_group("group-1.zip")

    conn = get(conn, "/master")
    assert html_response(conn, 200)
    {:ok, view, html} = live(conn)

    {:ok, %{conn: conn, view: view, html: html}}
  end

  defp open_scene_selector(view) do
    view |> element("#scene-selector-button") |> render_click()
  end

  defp select_scene(view, scene_name) do
    view |> element("#scene-selector button.item", scene_name) |> render_click()
  end

  defp first_scene_name do
    {:ok, %{scenes: [%{name: name} | _]}} = Adventures.get_loaded()
    name
  end

  defp second_scene_name do
    {:ok, %{scenes: [_, %{name: name} | _]}} = Adventures.get_loaded()
    name
  end

  test "opens and closes 'scene selector' with a click", %{view: view, html: html} do
    assert !find_html_element(html, "#scene-selector")

    open_scene_selector(view)
    assert find_html_element(render(view), "#scene-selector")

    open_scene_selector(view)
    assert !find_html_element(render(view), "#scene-selector")
  end

  test "selects 'scene selector' item with a click", %{view: view} do
    open_scene_selector(view)
    select_scene(view, first_scene_name())
    assert find_html_element(render(view), "button.item.selected")

    assert Enum.count(Game.get_state().scene.tokens) === 3
    first_token = Enum.at(Game.get_state().scene.tokens, 0)
    assert first_token.x == 100
    assert first_token.y == 200
    assert first_token.state == "unconscious"
  end

  test "unsets scene with a click", %{view: view} do
    open_scene_selector(view)
    select_scene(view, first_scene_name())
    assert find_html_element(render(view), "button.item.selected")

    view |> element("#unset_scene") |> render_click()
    assert !find_html_element(render(view), "#scene-selector .item.selected")
  end

  test "scene switching retains state", %{view: view} do
    open_scene_selector(view)
    select_scene(view, first_scene_name())

    initial_token_count = Enum.count(Game.get_state().scene.tokens)

    # Add a token to scene 0
    Game.run_action([:tokens, :add], "monster 1")
    assert Enum.count(Game.get_state().scene.tokens) === initial_token_count + 1

    # Switch to scene 1
    select_scene(view, second_scene_name())

    # Switch back to scene 0
    select_scene(view, first_scene_name())

    # Token should still be there
    assert Enum.count(Game.get_state().scene.tokens) === initial_token_count + 1
  end

  test "scene state isolation", %{view: view} do
    open_scene_selector(view)
    select_scene(view, first_scene_name())

    scene_0_tokens = Enum.count(Game.get_state().scene.tokens)

    # Add a token to scene 0
    Game.run_action([:tokens, :add], "monster 1")
    assert Enum.count(Game.get_state().scene.tokens) === scene_0_tokens + 1

    # Switch to scene 1 — should NOT have the extra token
    select_scene(view, second_scene_name())
    scene_1_tokens = Enum.count(Game.get_state().scene.tokens)
    assert scene_1_tokens !== scene_0_tokens + 1
  end

  test "unset preserves state", %{view: view} do
    open_scene_selector(view)
    select_scene(view, first_scene_name())

    # Add a token
    Game.run_action([:tokens, :add], "monster 1")
    token_count = Enum.count(Game.get_state().scene.tokens)

    # Unset
    view |> element("#unset_scene") |> render_click()
    assert Game.get_state().scene == nil

    # Re-select same scene — token should persist
    select_scene(view, first_scene_name())
    assert Enum.count(Game.get_state().scene.tokens) === token_count
  end

  test "reset clears state", %{view: view} do
    open_scene_selector(view)
    select_scene(view, first_scene_name())

    initial_token_count = Enum.count(Game.get_state().scene.tokens)

    # Add a token
    Game.run_action([:tokens, :add], "monster 1")
    assert Enum.count(Game.get_state().scene.tokens) === initial_token_count + 1

    # Reset (first click shows confirmation, second executes)
    view |> element("#reset_scene") |> render_click()
    view |> element("#reset_scene") |> render_click()
    assert Enum.count(Game.get_state().scene.tokens) === initial_token_count
  end

  test "reset persists after switch", %{view: view} do
    open_scene_selector(view)
    select_scene(view, first_scene_name())

    initial_token_count = Enum.count(Game.get_state().scene.tokens)

    # Add a token then reset
    Game.run_action([:tokens, :add], "monster 1")
    view |> element("#reset_scene") |> render_click()
    view |> element("#reset_scene") |> render_click()

    # Switch away and back
    select_scene(view, second_scene_name())
    select_scene(view, first_scene_name())

    # Should have reset state, not the modified state
    assert Enum.count(Game.get_state().scene.tokens) === initial_token_count
  end

  test "re-selecting same scene is a no-op", %{view: view} do
    open_scene_selector(view)
    select_scene(view, first_scene_name())

    # Add a token
    Game.run_action([:tokens, :add], "monster 1")
    token_count = Enum.count(Game.get_state().scene.tokens)

    # Re-select same scene
    select_scene(view, first_scene_name())

    # Token should still be there
    assert Enum.count(Game.get_state().scene.tokens) === token_count
  end

  test "reset and unset buttons disabled when no scene", %{view: view} do
    open_scene_selector(view)
    html = render(view)

    assert find_html_element(html, "#reset_scene[disabled]")
    assert find_html_element(html, "#unset_scene[disabled]")
  end
end
