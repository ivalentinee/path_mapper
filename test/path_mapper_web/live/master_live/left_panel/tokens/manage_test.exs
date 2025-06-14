defmodule PathMapperWeb.MasterLive.LeftPanel.Tokens.ManageTest do
  use PathMapperWeb.ConnCase
  import Phoenix.LiveViewTest

  alias PathMapper.Adventures
  alias PathMapper.Game

  setup %{conn: conn} do
    {:ok, adventure} = Adventures.load_adventure("adventure-1.zip")
    :ok = Game.run_action(:select_scene, 0)
    :ok = Game.run_action([:tokens, :add], 0)

    conn = get(conn, "/master")
    assert html_response(conn, 200)
    {:ok, view, html} = live(conn)

    {:ok, %{conn: conn, view: view, html: html, adventure: adventure}}
  end

  test "deletes a token", %{view: view, html: html} do
    assert !find_html_element(html, "#tokens")

    view |> element("#tokens-button") |> render_click()
    assert find_html_element(render(view), "#tokens")

    view |> element("#manage-tokens > :first-child > .delete") |> render_click()
    assert Enum.empty?(Game.get_state().scene.tokens)

    view |> element("#tokens-button") |> render_click()
    assert !find_html_element(render(view), "#tokens")
  end

  test "deletes a token using a keystroke", %{view: view, html: html} do
    assert !find_html_element(html, "#tokens")

    run_keystroke(view, ["p", "t"])
    assert find_html_element(render(view), "#tokens")

    run_keystroke(view, ["1", "x"])
    assert Enum.empty?(Game.get_state().scene.tokens)
  end
end
