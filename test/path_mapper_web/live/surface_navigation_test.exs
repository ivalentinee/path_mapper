defmodule PathMapperWeb.SurfaceNavigationTest do
  @moduledoc """
  A surface at its own address: what the page shows, and what it may do.

  The fixture holds two maps, so "the surface this page names" and "the surface
  the table is shown" can differ — which is the only interesting case.
  """
  use PathMapperWeb.ConnCase
  import Phoenix.LiveViewTest

  alias PathMapper.Game
  alias PathMapper.Session.Resolve

  @first "mt0001-0000000001"
  @second "mt0001-0000000002"

  setup %{conn: conn} do
    load_session()
    :ok = select_surface(1)
    {:ok, %{conn: conn}}
  end

  defp viewing(conn, path) do
    {:ok, view, _html} = conn |> get(path) |> live()
    view |> element("#scene") |> render_hook("geometry", %{"width" => 1600, "height" => 1000})
    view
  end

  defp shown(view), do: view |> render() |> find_html_element(".scene-indicator") |> Floki.text()

  describe "a surface at its own address" do
    test "the master's page shows the surface it names, not the table's", %{conn: conn} do
      assert Game.get_state().active_surface_id == @first

      assert shown(viewing(conn, "/master/#{@second}")) =~ "Крепость"
    end

    test "the player's page does too", %{conn: conn} do
      html = render(viewing(conn, "/#{@second}"))

      assert find_html_element(html, ".map-object")
    end

    test "the table's own page is unaffected", %{conn: conn} do
      assert shown(viewing(conn, "/master")) =~ "scene 1"
    end

    # An empty board reads as a session that failed to load.
    test "an id naming no surface is refused", %{conn: conn} do
      assert_raise PathMapperWeb.ViewedSurface.NotFound, fn ->
        conn |> get("/master/mt9999-0000000099") |> live()
      end
    end
  end

  describe "looking is not showing" do
    test "opening an address moves nobody", %{conn: conn} do
      viewing(conn, "/master/#{@second}")

      assert Game.get_state().active_surface_id == @first
    end

    test "a broadcast leaves the page on the surface it names", %{conn: conn} do
      view = viewing(conn, "/master/#{@second}")

      :ok = Game.run_action([:surface, :select], @first)
      Game.reconcile()

      assert shown(view) =~ "Крепость"
    end
  end

  describe "the button that makes it the table's" do
    test "is there when the page is not the table's", %{conn: conn} do
      html = render(viewing(conn, "/master/#{@second}"))

      assert find_html_element(html, ~s{button[phx-click="push_to_table"]})
    end

    test "a button that would do nothing is not drawn", %{conn: conn} do
      refute find_html_element(
               render(viewing(conn, "/master/#{@first}")),
               ~s{[phx-click="push_to_table"]}
             )

      refute find_html_element(render(viewing(conn, "/master")), ~s{[phx-click="push_to_table"]})
    end

    test "pressing it shows the table that surface", %{conn: conn} do
      view = viewing(conn, "/master/#{@second}")

      view |> element(~s{button[phx-click="push_to_table"]}) |> render_click()

      assert Game.get_state().active_surface_id == @second
    end

    # Once the page and the table name the same surface there is nothing left
    # to push, and the broadcast that follows the press says so.
    test "and then takes itself away", %{conn: conn} do
      view = viewing(conn, "/master/#{@second}")
      view |> element(~s{button[phx-click="push_to_table"]}) |> render_click()

      refute find_html_element(render(view), ~s{[phx-click="push_to_table"]})
    end

    test "the player's page has no such button", %{conn: conn} do
      refute find_html_element(
               render(viewing(conn, "/#{@second}")),
               ~s{[phx-click="push_to_table"]}
             )
    end
  end

  describe "the way to look" do
    test "opens beside the table's view, and in place anywhere else", %{conn: conn} do
      :ok = select_surface(1)
      table = conn |> get("/master") |> live() |> then(fn {:ok, view, _} -> view end)
      table |> element("#scene") |> render_hook("geometry", %{"width" => 1600, "height" => 1000})
      open_menu(table)

      assert Floki.attribute([preview(render(table))], "target") == ["_blank"]

      elsewhere = viewing(conn, "/master/#{@first}")
      open_menu(elsewhere)

      assert Floki.attribute([preview(render(elsewhere))], "target") == []
    end
  end

  defp preview(html), do: find_html_element(html, ".object-menu a.preview")

  defp open_menu(view) do
    index =
      Resolve.surface(@first).map_objects |> Enum.find_index(& &1.link)

    view
    |> element(~s{[data-object-index="#{index}"]})
    |> render_hook("object_context_menu", %{"index" => index, "x" => 10, "y" => 10})
  end
end
