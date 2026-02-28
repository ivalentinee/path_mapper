defmodule PathMapperWeb.MasterLive.LeftPanel.Tokens.ManageTest do
  use PathMapperWeb.ConnCase
  import Phoenix.LiveViewTest

  alias PathMapper.Adventures
  alias PathMapper.Game
  alias PathMapper.Groups

  setup %{conn: conn} do
    {:ok, _group} = Groups.load_group("group-1.zip")
    {:ok, adventure} = Adventures.load_adventure("adventure-1.zip")
    :ok = Game.run_action([:scene, :select], 0)
    :ok = Game.run_action([:tokens, :add], 0)

    conn = get(conn, "/master")
    assert html_response(conn, 200)
    {:ok, view, html} = live(conn)

    {:ok, %{conn: conn, view: view, html: html, adventure: adventure}}
  end

  test "deletes a token", %{view: view, html: html} do
    assert Enum.count(Game.get_state().scene.tokens) === 4

    assert !find_html_element(html, "#tokens")

    view |> element("#tokens-button") |> render_click()
    assert find_html_element(render(view), "#tokens")

    view |> element("#manage-tokens > :first-child .delete") |> render_click()
    assert Enum.count(Game.get_state().scene.tokens) === 3

    view |> element("#tokens-button") |> render_click()
    assert !find_html_element(render(view), "#tokens")
  end

  test "kills, knocks out and restores a token", %{view: view, html: html} do
    assert !find_html_element(html, "#tokens")

    view |> element("#tokens-button") |> render_click()
    assert find_html_element(render(view), "#tokens")

    view |> element("#manage-tokens > :first-child .dead") |> render_click()
    first_token = Enum.at(Game.get_state().scene.tokens, 0)
    assert first_token.state == "dead"

    view |> element("#manage-tokens > :first-child .unconscious") |> render_click()
    first_token = Enum.at(Game.get_state().scene.tokens, 0)
    assert first_token.state == "unconscious"

    view |> element("#manage-tokens > :first-child .alive") |> render_click()
    first_token = Enum.at(Game.get_state().scene.tokens, 0)
    assert first_token.state == "alive"
  end
end
