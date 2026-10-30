defmodule PathMapperWeb.MasterLive.LeftPanel.Tokens.ManageTest do
  use PathMapperWeb.ConnCase
  import Phoenix.LiveViewTest

  alias PathMapper.Game

  setup %{conn: conn} do
    load_party()
    load_session()
    :ok = select_surface(1)

    # Placements used to arrive with the scene. They are put down here instead.
    :ok = Game.run_action([:tokens, :add], "tk0001-0000000001")
    :ok = Game.run_action([:tokens, :add], "tk0001-0000000002")

    conn = get(conn, "/master")
    assert html_response(conn, 200)
    {:ok, view, html} = live(conn)

    {:ok, %{conn: conn, view: view, html: html}}
  end

  test "deletes a token", %{view: view, html: html} do
    assert Enum.count(Game.get_state().surface.tokens) === 2

    assert !find_html_element(html, "#tokens")

    view |> element("#tokens-button") |> render_click()
    assert find_html_element(render(view), "#tokens")

    view |> element("#manage-tokens > :first-child .delete") |> render_click()
    assert Enum.count(Game.get_state().surface.tokens) === 1

    view |> element("#tokens-button") |> render_click()
    assert !find_html_element(render(view), "#tokens")
  end

  test "kills, knocks out and restores a token", %{view: view, html: html} do
    assert !find_html_element(html, "#tokens")

    view |> element("#tokens-button") |> render_click()
    assert find_html_element(render(view), "#tokens")

    view |> element("#manage-tokens > :first-child .dead") |> render_click()
    first_token = Enum.at(Game.get_state().surface.tokens, 0)
    assert first_token.state == "dead"

    view |> element("#manage-tokens > :first-child .unconscious") |> render_click()
    first_token = Enum.at(Game.get_state().surface.tokens, 0)
    assert first_token.state == "unconscious"

    view |> element("#manage-tokens > :first-child .alive") |> render_click()
    first_token = Enum.at(Game.get_state().surface.tokens, 0)
    assert first_token.state == "alive"
  end
end
