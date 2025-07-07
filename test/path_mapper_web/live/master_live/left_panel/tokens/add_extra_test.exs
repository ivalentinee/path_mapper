defmodule PathMapperWeb.MasterLive.LeftPanel.Tokens.AddExtraTest do
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

  test "adds an extra token with a click", %{view: view, html: html} do
    assert !find_html_element(html, "#tokens")
    assert Enum.empty?(Game.get_state().scene.tokens)

    view |> element("#tokens-button") |> render_click()
    assert find_html_element(render(view), "#tokens")

    view |> element("#add-player-extra-button") |> render_click()
    assert find_html_element(render(view), "#add-extra-token")

    view
    |> element("#add-extra-token-player-0")
    |> render_click()

    view
    |> element("#add-extra-token-player-0 .add-extra-token-player-tokens > :first-child button")
    |> render_click()

    assert Enum.count(Game.get_state().scene.tokens) == 1

    view
    |> element("#add-extra-token-player-0 .add-extra-token-player-tokens > :first-child button")
    |> render_click()

    assert Enum.count(Game.get_state().scene.tokens) == 2
  end

  test "adds an extra token with a keystroke", %{view: view, html: html} do
    assert !find_html_element(html, "#tokens")
    assert Enum.empty?(Game.get_state().scene.tokens)

    run_keystroke(view, ["p", "t", "e"])
    assert find_html_element(render(view), "#add-extra-token")

    run_keystroke(view, ["1", "a", "1"])
    assert Enum.count(Game.get_state().scene.tokens) == 1

    run_keystroke(view, ["p", "t", "e", "1", "a", "1"])
    assert Enum.count(Game.get_state().scene.tokens) == 2
  end
end
