defmodule PathMapperWeb.MasterLive.LeftPanel.Tokens.AddTest do
  use PathMapperWeb.ConnCase
  import Phoenix.LiveViewTest

  alias PathMapper.Game

  setup %{conn: conn} do
    load_session()
    load_party()
    :ok = select_surface(1)

    # Placements used to arrive with the scene. They are put down here instead.
    :ok = Game.run_action([:tokens, :add], "tk0001-0000000001")
    :ok = Game.run_action([:tokens, :add], "tk0001-0000000002")

    conn = get(conn, "/master")
    assert html_response(conn, 200)
    {:ok, view, html} = live(conn)

    {:ok, %{conn: conn, view: view, html: html}}
  end

  test "expanded, the panel lists the adventure's tokens and filters them by name", %{view: view} do
    view |> element("#tokens-button") |> render_click()
    view |> element("#add-token-button") |> render_click()
    view |> element("#add-token [phx-click=toggle_expanded]") |> render_click()

    html = render(view)
    assert html =~ "monster 1"
    assert html =~ "NPC 1"

    view
    |> element("#add-token form[phx-change=search]")
    |> render_change(%{"search" => "monster"})

    filtered = render(view)
    assert filtered =~ "monster 1"
    refute filtered =~ "NPC 1"
  end

  test "adds a token", %{view: view, html: html} do
    token_count = Enum.count(Game.get_state().surface.tokens)

    assert !find_html_element(html, "#tokens")

    view |> element("#tokens-button") |> render_click()
    assert find_html_element(render(view), "#tokens")

    view |> element("#add-token-button") |> render_click()
    assert find_html_element(render(view), "#add-token")

    view |> element("[phx-click=add_token]", "monster 1") |> render_click()
    assert Enum.count(Game.get_state().surface.tokens) == token_count + 1

    view |> element("[phx-click=add_token]", "NPC 1") |> render_click()
    assert Enum.count(Game.get_state().surface.tokens) == token_count + 2
    last_token = List.last(Game.get_state().surface.tokens)
    assert is_integer(last_token.x)

    view |> element("#tokens-button") |> render_click()
    view |> element("#tokens-button") |> render_click()
    assert !find_html_element(render(view), "#tokens")
  end
end
