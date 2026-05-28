defmodule PathMapperWeb.Scene.RightPanelTest do
  use PathMapperWeb.ConnCase
  import Phoenix.LiveViewTest

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

    test "right panel renders with Group, Links, and snap-to-grid buttons", %{html: html} do
      assert find_html_element(html, ".right-panel")
      assert find_html_element(html, "#snap-to-grid")
      assert html =~ "Group"
      assert html =~ "Links"
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

    test "links button toggles panel open/closed", %{view: view} do
      assert !find_html_element(render(view), ".links-panel")

      view |> element(".right-panel-button", "Links") |> render_click()
      assert find_html_element(render(view), ".links-panel")

      view |> element(".right-panel-button", "Links") |> render_click()
      assert !find_html_element(render(view), ".links-panel")
    end

    test "links panel shows URL entries", %{view: view} do
      view |> element(".right-panel-button", "Links") |> render_click()
      html = render(view)

      assert find_html_element(html, ".links-entry")
      assert find_html_element(html, ".links-title")
    end

    test "links are anchor tags with href and target", %{view: view} do
      view |> element(".right-panel-button", "Links") |> render_click()
      html = render(view)

      assert html =~ "href=\"https://example.net/\""
      assert html =~ "target=\"_blank\""
      assert html =~ "rel=\"noopener noreferrer\""
    end

    test "mutual exclusion: opening Links closes Group", %{view: view} do
      view |> element(".right-panel-button", "Group") |> render_click()
      assert find_html_element(render(view), ".group-overview")

      view |> element(".right-panel-button", "Links") |> render_click()
      html = render(view)
      assert !find_html_element(html, ".group-overview")
      assert find_html_element(html, ".links-panel")
    end

    test "mutual exclusion: opening Group closes Links", %{view: view} do
      view |> element(".right-panel-button", "Links") |> render_click()
      assert find_html_element(render(view), ".links-panel")

      view |> element(".right-panel-button", "Group") |> render_click()
      html = render(view)
      assert !find_html_element(html, ".links-panel")
      assert find_html_element(html, ".group-overview")
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

    test "links panel works on player view", %{view: view} do
      view |> element(".right-panel-button", "Links") |> render_click()
      assert find_html_element(render(view), ".links-panel")
    end

    test "click outside closes right panel on player view", %{view: view} do
      view |> element(".right-panel-button", "Links") |> render_click()
      assert find_html_element(render(view), ".links-panel")

      view |> element(".player-container") |> render_click()
      assert !find_html_element(render(view), ".links-panel")
    end
  end

  describe "no adventure/group loaded" do
    setup %{conn: conn} do
      :persistent_term.erase(PathMapper.Adventures.Adventure)
      :persistent_term.erase(PathMapper.Groups.Group)

      conn = get(conn, "/master")
      assert html_response(conn, 200)
      {:ok, view, html} = live(conn)

      {:ok, %{view: view, html: html}}
    end

    test "links button hidden when no adventure loaded", %{html: html} do
      refute html =~ "toggle_links_panel"
    end

    test "group button hidden when no group loaded", %{html: html} do
      refute html =~ "toggle_group_panel"
    end
  end

  describe "empty URLs" do
    setup %{conn: conn} do
      load_adventure("adventure-2.zip")

      conn = get(conn, "/master")
      assert html_response(conn, 200)
      {:ok, view, html} = live(conn)

      {:ok, %{view: view, html: html}}
    end

    test "links panel with no URLs shows empty message", %{view: view} do
      view |> element(".right-panel-button", "Links") |> render_click()
      html = render(view)

      assert find_html_element(html, ".panel-empty")
      assert html =~ "No links in this adventure"
    end
  end
end
