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

  test "every kind reads as empty when the session holds nothing", %{view: view} do
    html = render(open(view))

    assert length(Floki.find(Floki.parse_document!(html), "#game-panel .empty-item")) == 4
  end

  test "counts what arrived, by kind", %{view: view} do
    load_session()
    load_party()

    html = render(open(view))
    rows = Floki.parse_document!(html) |> Floki.find("#game-panel .item")

    counts =
      Map.new(rows, fn row ->
        {row |> Floki.find(".item-name") |> Floki.text() |> String.trim(),
         row |> Floki.find(".item-id") |> Floki.text() |> String.trim()}
      end)

    assert counts["Maps"] == "2"
    assert counts["Characters"] == "2"
    assert counts["Wallpaper"] == "1"
    assert counts["Tokens"] == "7"
  end

  # There is no package to name any more, so there is nothing here that could
  # carry a title.
  test "names no package", %{view: view} do
    load_session()
    html = render(open(view))

    refute html =~ "Adventure example"
  end

  # The console reports; it does not compose. Nothing here changes what the server
  # holds, and nothing here moves a file.
  test "offers no control at all", %{view: view} do
    load_session()
    html = render(open(view))
    panel = html |> Floki.parse_document!() |> Floki.find("#game-panel")

    assert Floki.find(panel, "button") == []
    assert Floki.find(panel, "input") == []
    assert Floki.find(panel, "a[download]") == []
  end
end
