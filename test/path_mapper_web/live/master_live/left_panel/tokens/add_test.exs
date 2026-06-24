defmodule PathMapperWeb.MasterLive.LeftPanel.Tokens.AddTest do
  use PathMapperWeb.ConnCase
  import Phoenix.LiveViewTest

  alias PathMapper.Game
  alias PathMapper.Groups

  setup %{conn: conn} do
    load_adventure("adventure-1.zip")
    {:ok, _group} = Groups.load_group("group-1.zip")
    :ok = Game.run_action([:scene, :select], 0)

    conn = get(conn, "/master")
    assert html_response(conn, 200)
    {:ok, view, html} = live(conn)

    {:ok, %{conn: conn, view: view, html: html}}
  end

  test "adds a token", %{view: view, html: html} do
    token_count = Enum.count(Game.get_state().scene.tokens)

    assert !find_html_element(html, "#tokens")

    view |> element("#tokens-button") |> render_click()
    assert find_html_element(render(view), "#tokens")

    view |> element("#add-token-button") |> render_click()
    assert find_html_element(render(view), "#add-token")

    view |> element("[phx-click=add_token]", "monster 1") |> render_click()
    assert Enum.count(Game.get_state().scene.tokens) == token_count + 1

    view |> element("[phx-click=add_token]", "NPC 1") |> render_click()
    assert Enum.count(Game.get_state().scene.tokens) == token_count + 2
    last_token = List.last(Game.get_state().scene.tokens)
    assert last_token.x == 200

    view |> element("#tokens-button") |> render_click()
    view |> element("#tokens-button") |> render_click()
    assert !find_html_element(render(view), "#tokens")
  end
end
