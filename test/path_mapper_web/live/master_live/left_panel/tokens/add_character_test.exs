defmodule PathMapperWeb.MasterLive.LeftPanel.Tokens.AddCharacterTest do
  use PathMapperWeb.ConnCase
  import Phoenix.LiveViewTest

  alias PathMapper.Game

  setup %{conn: conn} do
    load_session()
    load_party()
    :ok = select_surface(1)

    conn = get(conn, "/master")
    assert html_response(conn, 200)
    {:ok, view, html} = live(conn)

    {:ok, %{conn: conn, view: view, html: html}}
  end

  test "adds a player token", %{view: view, html: html} do
    token_count = Enum.count(Game.get_state().surface.tokens)

    assert !find_html_element(html, "#tokens")

    view |> element("#tokens-button") |> render_click()
    assert find_html_element(render(view), "#tokens")

    view |> element("#add-player-token-button") |> render_click()
    assert find_html_element(render(view), "#add-player-token")

    view |> element("#add-player-token-players > :first-child button") |> render_click()
    assert Enum.count(Game.get_state().surface.tokens) == token_count + 1
  end

  test "adds a token for each player", %{view: view, html: html} do
    token_count = Enum.count(Game.get_state().surface.tokens)

    assert !find_html_element(html, "#tokens")

    view |> element("#tokens-button") |> render_click()
    view |> element("#add-player-token-button") |> render_click()
    view |> element("#add-player-token #add-all-players") |> render_click()
    assert Enum.count(Game.get_state().surface.tokens) == token_count + 2
  end
end
