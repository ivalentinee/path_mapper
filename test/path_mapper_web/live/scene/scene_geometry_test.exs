defmodule PathMapperWeb.Scene.SceneGeometryTest do
  use PathMapperWeb.ConnCase
  import Phoenix.LiveViewTest

  # The map a scene shows is fitted to the viewport, so two scenes whose maps have
  # different shapes must render at different sizes. This went wrong once and went
  # unnoticed: the staleness check matched on a scene field that had been removed,
  # the clause silently stopped matching, and every scene after the first kept the
  # previous one's scaling. Nothing caught it because no fixture had two scenes
  # whose maps were shaped differently.
  @adventure "tt0001-0000000004-two-shapes.zip"

  setup %{conn: conn} do
    load_adventure(@adventure)
    {:ok, _group} = load_group("tg0001-0000000001-group-1.zip")

    conn = get(conn, "/master")
    {:ok, view, _html} = live(conn)

    {:ok, %{view: view}}
  end

  # The geometry reaches the page as an inline style, so that is what is read.
  defp rendered_map_style(view) do
    view
    |> render()
    |> Floki.parse_document!()
    |> Floki.find("[style]")
    |> Floki.attribute("style")
    |> Enum.find(&String.contains?(&1, "width:"))
  end

  defp select(view, position) do
    id = PathMapper.Game.scene_id_at(position)
    PathMapper.Game.run_action([:scene, :select], id)
    render(view)
    id
  end

  # The viewport is measured in the browser and pushed in. Without a browser the
  # server has no size to fit a map to, so the test supplies one the way the hook
  # does: once, on mount, and never again.
  #
  # Once only is the whole point. That handler rebuilds the geometry
  # unconditionally, so reporting the viewport after each switch would rebuild it
  # whether or not the switch was noticed - and the test would pass against the very
  # bug it exists to catch. It did, before this comment was here.
  defp report_viewport(view) do
    view
    |> element("#scene")
    |> render_hook("geometry", %{"width" => 1600, "height" => 1000})
  end

  test "a square scene and a wide scene render at different sizes", %{view: view} do
    select(view, 1)
    report_viewport(view)
    square = rendered_map_style(view)

    select(view, 2)
    wide = rendered_map_style(view)

    assert square, "the first scene rendered no map geometry"
    refute square == wide, "switching scenes kept the previous scene's geometry: #{square}"
  end
end
