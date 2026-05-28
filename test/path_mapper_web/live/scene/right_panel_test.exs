defmodule PathMapperWeb.Scene.RightPanelTest do
  use PathMapperWeb.ConnCase
  import Phoenix.LiveViewTest

  alias PathMapper.Game
  alias PathMapper.Groups

  describe "GM view" do
    setup %{conn: conn} do
      load_adventure("adventure-1.zip")
      {:ok, _group} = Groups.load_group("group-1.zip")

      conn = get(conn, "/master")
      assert html_response(conn, 200)
      {:ok, view, html} = live(conn)

      {:ok, %{view: view, html: html}}
    end

    test "right panel renders with Group and snap-to-grid buttons", %{html: html} do
      assert find_html_element(html, ".right-panel")
      assert find_html_element(html, "#snap-to-grid")
    end

    test "group button toggles panel open/closed", %{view: view} do
      assert !find_html_element(render(view), ".group-overview")

      view |> element(".right-panel-button", "Group") |> render_click()
      assert find_html_element(render(view), ".group-overview")

      view |> element(".right-panel-button", "Group") |> render_click()
      assert !find_html_element(render(view), ".group-overview")
    end

    test "group panel shows character entries", %{view: view} do
      view |> element(".right-panel-button", "Group") |> render_click()
      html = render(view)

      assert find_html_element(html, ".group-character")
      assert find_html_element(html, ".group-character-name")
      assert find_html_element(html, ".group-character-player")
    end

    test "character with class shows class", %{view: view} do
      view |> element(".right-panel-button", "Group") |> render_click()
      html = render(view)

      assert find_html_element(html, ".group-character-class")
    end

    test "group title is displayed", %{view: view} do
      view |> element(".right-panel-button", "Group") |> render_click()
      html = render(view)

      assert find_html_element(html, ".group-title")
    end

    test "snap-to-grid toggles", %{view: view} do
      view |> element("#snap-to-grid") |> render_click()
      view |> element("#snap-to-grid") |> render_click()
    end
  end

  describe "Player view" do
    setup %{conn: conn} do
      load_adventure("adventure-1.zip")
      {:ok, _group} = Groups.load_group("group-1.zip")

      conn = get(conn, "/")
      assert html_response(conn, 200)
      {:ok, view, html} = live(conn)

      {:ok, %{view: view, html: html}}
    end

    test "right panel renders on player view", %{html: html} do
      assert find_html_element(html, ".right-panel")
    end

    test "group panel works on player view", %{view: view} do
      view |> element(".right-panel-button", "Group") |> render_click()
      assert find_html_element(render(view), ".group-overview")
    end
  end
end
