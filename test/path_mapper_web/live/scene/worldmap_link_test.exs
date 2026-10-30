defmodule PathMapperWeb.Scene.WorldmapLinkTest do
  @moduledoc """
  A map pointing at a map, from the layer name through to the table moving.

  The fixture carries the two cases that differ: map 1's `Table` links to map 2
  and is titled, map 2's `Table` links back and is marked `gm`.
  """
  use PathMapperWeb.ConnCase
  import Phoenix.LiveViewTest

  alias PathMapper.Game
  alias PathMapper.Session.Resolve
  alias PathMapper.Session.Store

  @first "mt0001-0000000001"
  @second "mt0001-0000000002"

  setup %{conn: conn} do
    load_session()
    {:ok, %{conn: conn}}
  end

  defp master(conn), do: conn |> get("/master") |> live() |> viewing()

  defp player(conn), do: conn |> get("/") |> live() |> viewing()

  # The viewport is measured in the browser and pushed in; without it the scene
  # renders empty and there is nothing to assert against.
  defp viewing({:ok, view, _html}) do
    view |> element("#scene") |> render_hook("geometry", %{"width" => 1600, "height" => 1000})
    view
  end

  defp open_menu(view, index) do
    view
    |> element(~s{[data-object-index="#{index}"]})
    |> render_hook("object_context_menu", %{"index" => index, "x" => 10, "y" => 10})
  end

  defp linked_object_index(map_id) do
    Resolve.surface(map_id).map_objects
    |> Enum.find_index(& &1.link)
  end

  describe "a link reaches the board" do
    test "the map's object arrives with its link parsed" do
      object = Enum.find(Resolve.surface(@first).map_objects, & &1.link)

      assert object.link.target == @second
      assert object.link.title == "The Wide Place"
      refute object.link.gm
    end
  end

  describe "what each rendering draws" do
    test "a linked object is marked and titled for the game master", %{conn: conn} do
      :ok = select_surface(1)
      html = render(master(conn))

      assert html =~ ~s{title="The Wide Place"}
      assert html =~ "map-object"
      assert find_html_element(html, ".map-object.link")
    end

    test "a linked object is marked and titled for a player too", %{conn: conn} do
      :ok = select_surface(1)
      html = render(player(conn))

      assert html =~ ~s{title="The Wide Place"}
      assert find_html_element(html, ".map-object.link")
    end

    test "a gm link is marked for the game master", %{conn: conn} do
      :ok = select_surface(2)

      assert find_html_element(render(master(conn)), ".map-object.link")
    end

    # The object keeps drawing - it is part of the map - but it is scenery.
    test "a gm link draws as plain scenery for a player", %{conn: conn} do
      :ok = select_surface(2)
      html = render(player(conn))

      assert html =~ "map-object"
      refute find_html_element(html, ".map-object.link")
    end
  end

  describe "following" do
    test "the game master's menu offers a way through", %{conn: conn} do
      :ok = select_surface(1)
      view = master(conn)
      index = linked_object_index(@first)

      open_menu(view, index)

      assert find_html_element(render(view), ~s{button[phx-click="object_follow_link"]})
    end

    test "taking it shows the table that map", %{conn: conn} do
      :ok = select_surface(1)
      view = master(conn)
      index = linked_object_index(@first)

      open_menu(view, index)
      view |> element(~s{button[phx-click="object_follow_link"]}) |> render_click()

      assert Game.get_state().surface.id == @second
    end

    # Guarded twice over: no hook is attached in the player view, so the event
    # cannot be fired from a browser at all, and scene_component.ex:40-43 refuses
    # every object_* event that reaches it anyway.
    test "a player has no way to follow", %{conn: conn} do
      :ok = select_surface(1)
      view = player(conn)
      index = linked_object_index(@first)

      object = find_html_element(render(view), ~s{[data-object-index="#{index}"]})

      assert object, "the object is drawn"
      assert Floki.attribute([object], "phx-hook") == []
      refute find_html_element(render(view), ".token-context-menu")
    end
  end

  describe "a link the session cannot match" do
    test "leaves the table where it is, and says nothing" do
      :ok = select_surface(1)

      assert :ok = Game.run_action([:surface, :select], "mt9999-0000000099") |> normalise()
      assert Game.get_state().surface.id == @first
    end

    # Reproduced before the guard existed: this raised inside the Agent and took
    # the whole session's game state down with it.
    test "a target that is not an id at all answers rather than raising" do
      :ok = select_surface(1)

      assert Game.run_action([:surface, :select], nil) == :ok
      assert Game.get_state().surface.id == @first
    end
  end

  defp normalise({:error, _reason}), do: :ok

  describe "what a map says about itself" do
    # The file is named scene-2; the [M] layer overrules it.
    test "an [M] layer names the map, beating the name the command declared" do
      assert Resolve.surface(@second).name == "Крепость Чёрного Камня"
      assert Resolve.surface(@second).url == "https://example.com/keep?a=1&b=2"
    end

    test "a map with no [M] layer is named by its filename and points nowhere" do
      assert Resolve.surface(@first).name == "scene 1"
      assert Resolve.surface(@first).url == nil
    end
  end

  describe "the menu the game master opens" do
    setup %{conn: conn} do
      :ok = select_surface(1)
      view = master(conn)
      open_menu(view, linked_object_index(@first))

      {:ok, %{html: render(view)}}
    end

    test "names the target below the ways out", %{html: html} do
      assert html =~ "Крепость Чёрного Камня"
      assert find_html_element(html, ".object-menu .menu-name")
    end

    test "offers the target's url in a separate tab", %{html: html} do
      link = find_html_element(html, ".object-menu a.url")

      assert Floki.attribute([link], "href") == ["https://example.com/keep?a=1&b=2"]
      assert Floki.attribute([link], "target") == ["_blank"]
      assert Floki.attribute([link], "rel") == ["noopener noreferrer"]
    end

    test "draws the way through and the way to look", %{html: html} do
      assert find_html_element(html, ~s{.object-menu button.go[phx-click="object_follow_link"]})

      preview = find_html_element(html, ".object-menu a.preview")

      assert Floki.attribute([preview], "href") == ["/master/#{@second}"]
      # The table's own view may not be replaced, so looking opens beside it.
      assert Floki.attribute([preview], "target") == ["_blank"]
    end

    test "keeps the object's own buttons", %{html: html} do
      assert find_html_element(html, ~s{button[phx-click="object_toggle_lock"]})
      assert find_html_element(html, ~s{button[phx-click="object_reset_position"]})
    end
  end

  describe "what the menu leaves out" do
    test "a target with no url is named, and offered no way out of PathMapper", %{conn: conn} do
      :ok = select_surface(2)
      view = master(conn)
      open_menu(view, linked_object_index(@second))
      html = render(view)

      assert find_html_element(html, ".object-menu .menu-name")
      refute find_html_element(html, ".object-menu a.url")
      assert find_html_element(html, ".object-menu button.go")
    end

    # The report a dead link gives is that there is no way through to press.
    test "a link naming nothing loses the whole of the first row", %{conn: conn} do
      :ok = select_surface(1)
      view = master(conn)
      Store.delete(@second)

      open_menu(view, linked_object_index(@first))
      html = render(view)

      refute find_html_element(html, ".object-menu button.go")
      refute find_html_element(html, ".object-menu button.preview")
      refute find_html_element(html, ".object-menu .menu-name")
      assert find_html_element(html, ~s{button[phx-click="object_toggle_lock"]})
    end

    test "an object with no link opens the object's buttons alone", %{conn: conn} do
      :ok = select_surface(1)
      view = master(conn)
      index = Enum.find_index(Resolve.surface(@first).map_objects, &(&1.link == nil))

      open_menu(view, index)
      html = render(view)

      refute find_html_element(html, ".object-menu .menu-row + .menu-row")
      assert find_html_element(html, ~s{button[phx-click="object_toggle_show"]})
    end
  end

  describe "a menu whose object may have moved" do
    # An open menu holds an index, and an index is all a map object has. After
    # the surface changes, that index names a different object - so the menu
    # would show the wrong map's name and act on the wrong thing.
    test "closes when the surface changes under it", %{conn: conn} do
      :ok = select_surface(1)
      view = master(conn)
      open_menu(view, linked_object_index(@first))

      assert find_html_element(render(view), ".object-menu")

      :ok = select_surface(2)

      refute find_html_element(render(view), ".object-menu")
    end
  end

  defp normalise(other), do: other
end
