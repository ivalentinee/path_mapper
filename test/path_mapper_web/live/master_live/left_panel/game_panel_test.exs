defmodule PathMapperWeb.MasterLive.LeftPanel.GamePanelTest do
  use PathMapperWeb.ConnCase
  import Phoenix.LiveViewTest

  setup %{conn: conn} do
    conn = get(conn, "/master")
    assert html_response(conn, 200)
    {:ok, view, html} = live(conn)

    {:ok, %{conn: conn, view: view, html: html}}
  end

  defp open(view) do
    view |> element("#game-panel-button") |> render_click()
    view
  end

  defp text_of(html, selector) do
    html |> find_html_element(selector) |> Floki.text() |> String.trim()
  end

  test "opens with a click", %{view: view, html: html} do
    refute find_html_element(html, "#game-panel")
    assert find_html_element(render(open(view)), "#game-panel")
  end

  test "says so when the session holds nothing", %{view: view} do
    html = render(open(view))

    assert length(Floki.find(Floki.parse_document!(html), "#game-panel .empty-item")) == 2
  end

  test "shows the adventure and the group together", %{view: view} do
    load_adventure("tt0001-0000000001-adventure-1.zip")
    {:ok, _group} = load_group("tg0001-0000000001-group-1.zip")

    html = render(open(view))

    ids =
      Floki.parse_document!(html) |> Floki.find("#game-panel .item-id") |> Enum.map(&Floki.text/1)

    assert "tt0001-0000000001" in ids
    assert "tg0001-0000000001" in ids
  end

  test "shows the adventure's title", %{view: view} do
    load_adventure("tt0001-0000000001-adventure-1.zip")

    assert text_of(render(open(view)), "#game-panel .loaded-item .item-name") ==
             "Adventure example"
  end

  # The console reports; it does not compose. Nothing here changes what the server
  # holds, and nothing here moves a file.
  test "offers no control at all", %{view: view} do
    load_adventure("tt0001-0000000001-adventure-1.zip")
    html = render(open(view))
    panel = html |> Floki.parse_document!() |> Floki.find("#game-panel")

    assert Floki.find(panel, "button") == []
    assert Floki.find(panel, "input") == []
    assert Floki.find(panel, "a[download]") == []
  end
end
