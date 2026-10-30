defmodule PathMapperWeb.MasterLive.LeftPanel.SurfaceSelectorTest do
  use PathMapperWeb.ConnCase
  import Phoenix.LiveViewTest

  alias PathMapper.Game
  alias PathMapper.Session.Resolve

  setup %{conn: conn} do
    load_session()
    load_party()

    conn = get(conn, "/master")
    assert html_response(conn, 200)
    {:ok, view, html} = live(conn)

    {:ok, %{conn: conn, view: view, html: html}}
  end

  defp open_surface_selector(view) do
    view |> element("#surface-selector-button") |> render_click()
  end

  defp select_surface(view, scene_name) do
    view |> element("#surface-selector button.item", scene_name) |> render_click()
  end

  defp first_scene_name do
    [%{name: name} | _] = Resolve.surfaces()
    name
  end

  defp second_scene_name do
    [_, %{name: name} | _] = Resolve.surfaces()
    name
  end

  test "opens and closes 'scene selector' with a click", %{view: view, html: html} do
    assert !find_html_element(html, "#surface-selector")

    open_surface_selector(view)
    assert find_html_element(render(view), "#surface-selector")

    open_surface_selector(view)
    assert !find_html_element(render(view), "#surface-selector")
  end

  test "selects 'scene selector' item with a click", %{view: view} do
    open_surface_selector(view)
    select_surface(view, first_scene_name())
    assert find_html_element(render(view), "button.item.selected")

    # A surface arrives empty: nothing is placed until someone places it.
    assert Game.get_state().surface.tokens == []
  end

  test "unsets scene with a click", %{view: view} do
    open_surface_selector(view)
    select_surface(view, first_scene_name())
    assert find_html_element(render(view), "button.item.selected")

    view |> element("#unset_surface") |> render_click()
    assert !find_html_element(render(view), "#surface-selector .item.selected")
  end

  test "scene switching retains state", %{view: view} do
    open_surface_selector(view)
    select_surface(view, first_scene_name())

    initial_token_count = Enum.count(Game.get_state().surface.tokens)

    # Add a token to scene 0
    Game.run_action([:tokens, :add], "tk0001-0000000001")
    assert Enum.count(Game.get_state().surface.tokens) === initial_token_count + 1

    # Switch to scene 1
    select_surface(view, second_scene_name())

    # Switch back to scene 0
    select_surface(view, first_scene_name())

    # Token should still be there
    assert Enum.count(Game.get_state().surface.tokens) === initial_token_count + 1
  end

  test "scene state isolation", %{view: view} do
    open_surface_selector(view)
    select_surface(view, first_scene_name())

    scene_0_tokens = Enum.count(Game.get_state().surface.tokens)

    # Add a token to scene 0
    Game.run_action([:tokens, :add], "tk0001-0000000001")
    assert Enum.count(Game.get_state().surface.tokens) === scene_0_tokens + 1

    # Switch to scene 1 — should NOT have the extra token
    select_surface(view, second_scene_name())
    scene_1_tokens = Enum.count(Game.get_state().surface.tokens)
    assert scene_1_tokens !== scene_0_tokens + 1
  end

  test "unset preserves state", %{view: view} do
    open_surface_selector(view)
    select_surface(view, first_scene_name())

    # Add a token
    Game.run_action([:tokens, :add], "tk0001-0000000001")
    token_count = Enum.count(Game.get_state().surface.tokens)

    # Unset
    view |> element("#unset_surface") |> render_click()
    assert Game.get_state().surface == nil

    # Re-select same scene — token should persist
    select_surface(view, first_scene_name())
    assert Enum.count(Game.get_state().surface.tokens) === token_count
  end

  test "reset clears state", %{view: view} do
    open_surface_selector(view)
    select_surface(view, first_scene_name())

    initial_token_count = Enum.count(Game.get_state().surface.tokens)

    # Add a token
    Game.run_action([:tokens, :add], "tk0001-0000000001")
    assert Enum.count(Game.get_state().surface.tokens) === initial_token_count + 1

    # Reset (first click shows confirmation, second executes)
    view |> element("#reset_surface") |> render_click()
    view |> element("#reset_surface") |> render_click()
    assert Enum.count(Game.get_state().surface.tokens) === initial_token_count
  end

  test "reset persists after switch", %{view: view} do
    open_surface_selector(view)
    select_surface(view, first_scene_name())

    initial_token_count = Enum.count(Game.get_state().surface.tokens)

    # Add a token then reset
    Game.run_action([:tokens, :add], "tk0001-0000000001")
    view |> element("#reset_surface") |> render_click()
    view |> element("#reset_surface") |> render_click()

    # Switch away and back
    select_surface(view, second_scene_name())
    select_surface(view, first_scene_name())

    # Should have reset state, not the modified state
    assert Enum.count(Game.get_state().surface.tokens) === initial_token_count
  end

  test "re-selecting same scene is a no-op", %{view: view} do
    open_surface_selector(view)
    select_surface(view, first_scene_name())

    # Add a token
    Game.run_action([:tokens, :add], "tk0001-0000000001")
    token_count = Enum.count(Game.get_state().surface.tokens)

    # Re-select same scene
    select_surface(view, first_scene_name())

    # Token should still be there
    assert Enum.count(Game.get_state().surface.tokens) === token_count
  end

  test "reset and unset buttons disabled when no scene", %{view: view} do
    open_surface_selector(view)
    html = render(view)

    assert find_html_element(html, "#reset_surface[disabled]")
    assert find_html_element(html, "#unset_surface[disabled]")
  end
end
