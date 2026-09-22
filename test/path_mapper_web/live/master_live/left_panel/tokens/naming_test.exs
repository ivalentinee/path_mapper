defmodule PathMapperWeb.MasterLive.LeftPanel.Tokens.NamingTest do
  @moduledoc "Property 5: a placement's name is set and cleared from the GM's interface."
  use PathMapperWeb.ConnCase
  import Phoenix.LiveViewTest

  alias PathMapper.Game
  alias PathMapper.Game.State.Scene.Token, as: GameToken

  @fallen "tk0001-0000000001-fallen"
  @standing "tk0001-0000000001-standing"

  setup %{conn: conn} do
    {:ok, _group} = load_group("tg0001-0000000001-group-1.zip")
    load_adventure("tt0001-0000000001-adventure-1.zip")
    :ok = select_scene(1)

    conn = get(conn, "/master")
    {:ok, view, _html} = live(conn)

    view |> element("#tokens-button") |> render_click()

    {:ok, %{view: view}}
  end

  defp shown(game_id) do
    Game.get_state().scene.tokens
    |> Enum.find(&(&1.game_id == game_id))
    |> GameToken.displayed_name()
  end

  defp open_editor(view, game_id) do
    view |> element(~s{button.rename-button[phx-value-game-id="#{game_id}"]}) |> render_click()
  end

  test "the game master names a placement", %{view: view} do
    open_editor(view, @fallen)

    view
    |> element(~s{form.token-naming[phx-value-game-id="#{@fallen}"]})
    |> render_submit(%{"name" => "crooked ear"})

    assert shown(@fallen) == "crooked ear"
    assert render(view) =~ "crooked ear"
  end

  test "naming one placement leaves its sibling showing the declaration's", %{view: view} do
    declared = shown(@standing)
    open_editor(view, @fallen)

    view
    |> element(~s{form.token-naming[phx-value-game-id="#{@fallen}"]})
    |> render_submit(%{"name" => "crooked ear"})

    assert shown(@standing) == declared
  end

  test "the game master clears a name back to the declaration's", %{view: view} do
    declared = shown(@fallen)
    :ok = Game.run_action([:tokens, @fallen, :set_name], "crooked ear")

    open_editor(view, @fallen)

    view
    |> element(~s{button.token-naming-clear[phx-value-game-id="#{@fallen}"]})
    |> render_click()

    assert shown(@fallen) == declared
  end

  # Single focus: a placement is never being renamed and reassigned at once.
  test "opening the owner selector closes the name editor", %{view: view} do
    open_editor(view, @fallen)
    assert find_html_element(render(view), "form.token-naming")

    view |> element(~s{button.owner-button[phx-value-index="0"]}) |> render_click()

    refute find_html_element(render(view), "form.token-naming")
    assert find_html_element(render(view), ".owner-selector")
  end

  test "opening the name editor closes the owner selector", %{view: view} do
    view |> element(~s{button.owner-button[phx-value-index="0"]}) |> render_click()
    assert find_html_element(render(view), ".owner-selector")

    open_editor(view, @fallen)

    refute find_html_element(render(view), ".owner-selector")
    assert find_html_element(render(view), "form.token-naming")
  end
end
