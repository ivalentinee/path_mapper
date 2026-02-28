defmodule PathMapperWeb.MasterLive.LeftPanel.Tokens.AddPlayerTest do
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

  test "adds a player token", %{view: view, html: html} do
    token_count = Enum.count(Game.get_state().scene.tokens)

    assert !find_html_element(html, "#tokens")

    view |> element("#tokens-button") |> render_click()
    assert find_html_element(render(view), "#tokens")

    view |> element("#add-player-token-button") |> render_click()
    assert find_html_element(render(view), "#add-player-token")

    view |> element("#add-player-token-players > :first-child button") |> render_click()
    assert Enum.count(Game.get_state().scene.tokens) == token_count + 1
  end

  test "adds a token for each player", %{view: view, html: html} do
    token_count = Enum.count(Game.get_state().scene.tokens)

    assert !find_html_element(html, "#tokens")

    view |> element("#tokens-button") |> render_click()
    view |> element("#add-player-token-button") |> render_click()
    view |> element("#add-player-token #add-all-players") |> render_click()
    assert Enum.count(Game.get_state().scene.tokens) == token_count + 2
  end
end
