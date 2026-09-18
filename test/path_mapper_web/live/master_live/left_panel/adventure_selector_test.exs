defmodule PathMapperWeb.MasterLive.LeftPanel.AdventureSelectorTest do
  use PathMapperWeb.ConnCase
  import Phoenix.LiveViewTest

  setup %{conn: conn} do
    conn = get(conn, "/master")
    assert html_response(conn, 200)
    {:ok, view, html} = live(conn)

    {:ok, %{conn: conn, view: view, html: html}}
  end

  defp open(view) do
    view |> element("#adventure-selector-button") |> render_click()
    view
  end

  test "opens 'adventure selector' with a click", %{view: view, html: html} do
    assert !find_html_element(html, "#adventure-selector")
    assert find_html_element(render(open(view)), "#adventure-selector")
  end

  test "offers no library to browse", %{view: view} do
    html = render(open(view))

    refute find_html_element(html, "#adventure-selector button.item")
    refute find_html_element(html, ~s(#adventure-selector button[phx-click="reload"]))
  end

  test "restore is offered with no adventure loaded, and saving is not", %{view: view} do
    PathMapper.Game.clear()
    html = render(open(view))

    assert find_html_element(html, "#state-restore-input")
    refute find_html_element(html, ".state-buttons a[download]")
  end

  test "shows the loaded adventure's name and id", %{view: view} do
    load_adventure("tt0001-0000000001-adventure-1.zip")
    html = render(open(view))

    assert Floki.text(find_html_element(html, "#adventure-selector .loaded-item .item-name")) ==
             "Adventure example"

    assert Floki.text(find_html_element(html, "#adventure-selector .loaded-item .item-id")) ==
             "tt0001-0000000001"
  end

  # The console no longer initiates a load, so it no longer reports one failing:
  # a command's failure goes back to the client that sent it.
  test "offers no error overlay to dismiss", %{view: view} do
    refute find_html_element(render(open(view)), ".load-errors-overlay")
  end
end
