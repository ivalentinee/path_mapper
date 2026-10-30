defmodule PathMapperWeb.Scene.GridSourceTest do
  @moduledoc """
  Which grid is drawn, and whether one is drawn at all.

  A map may paint its own grid on a `[G]` layer. Where it has, that image is
  the grid — `docs/maps.md` says so — and the generated one is for a map that
  supplied none. The two used to be branched on visibility rather than on which
  the map provided, so a painted grid was only ever drawn by a map that had
  asked for no grid at all.
  """
  use PathMapperWeb.ConnCase
  import Phoenix.LiveViewTest

  alias PathMapper.Session.Entity
  alias PathMapper.Session.Store
  alias PathMapperWeb.Scene.SceneComponent
  alias PathMapperWeb.Scene.SceneState

  @painted "mt0001-0000000001"

  setup do
    load_session()
    :ok = select_surface(1)
    :ok
  end

  defp scene(override \\ false), do: %SceneState{grid_override: override}
  defp state, do: PathMapper.Game.get_state()

  describe "a map that painted its own grid" do
    test "has that image drawn, not a generated one" do
      assert {:painted, layer} = SceneComponent.grid_source(state(), scene())
      assert layer.image
    end

    test "and the page shows the image rather than drawn lines", %{conn: conn} do
      {:ok, view, _html} = conn |> get("/master") |> live()
      view |> element("#scene") |> render_hook("geometry", %{"width" => 1600, "height" => 1000})
      html = render(view)

      assert find_html_element(html, ".grid-container image")
      refute find_html_element(html, ".grid-container line")
    end
  end

  describe "a map that painted none" do
    setup do
      stripped = Store.fetch(@painted, "map") |> then(fn {:ok, entity} -> entity end)
      {:ok, bare} = Entity.build("map", %{"id" => @painted, "file" => stripped.data.file})
      {:ok, _} = Store.put(%{bare | data: %{bare.data | grid: nil}})
      PathMapper.Game.reconcile()
      :ok = select_surface(1)
      :ok
    end

    test "falls back to the generated grid" do
      assert SceneComponent.grid_source(state(), scene()) == :generated
    end
  end

  describe "a map that asked for no grid" do
    setup do
      {:ok, entity} = Store.fetch(@painted, "map")
      {:ok, _} = Store.put(%{entity | data: %{entity.data | show_grid: false}})
      PathMapper.Game.reconcile()
      :ok = select_surface(1)
      :ok
    end

    test "draws nothing" do
      assert SceneComponent.grid_source(state(), scene()) == :none
    end

    # The override is the game master's own view, and it reveals whichever
    # source the map would have used.
    test "unless the game master overrides, and then its own image comes back" do
      assert {:painted, _layer} = SceneComponent.grid_source(state(), scene(true))
    end
  end
end
