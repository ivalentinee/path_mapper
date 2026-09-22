defmodule PathMapperWeb.Scene.ObjectLightingTest do
  @moduledoc """
  A map object sits on a layer and is lit by it.

  The layer's own image took its lighting from a CSS class while its objects took
  only its visibility, so dimming a layer dimmed the floor and left the furniture
  on it bright.
  """
  use PathMapperWeb.ConnCase
  import Phoenix.LiveViewTest

  alias PathMapper.Game

  setup %{conn: conn} do
    load_adventure("tt0001-0000000001-adventure-1.zip")
    {:ok, _group} = load_group("tg0001-0000000001-group-1.zip")
    :ok = select_scene(1)

    conn = get(conn, "/master")
    {:ok, view, _html} = live(conn)
    view |> element("#scene") |> render_hook("geometry", %{"width" => 1600, "height" => 1000})

    {:ok, %{view: view}}
  end

  defp object_classes(view) do
    view
    |> render()
    |> Floki.parse_document!()
    |> Floki.find(".objects-container .map-object")
    |> Floki.attribute("class")
  end

  defp layer_of_first_object do
    scene = Game.get_state().scene
    [object | _] = scene.map.map_objects
    object.layer_index
  end

  test "an object on a bright layer carries no lighting class", %{view: view} do
    assert object_classes(view) != []
    assert Enum.all?(object_classes(view), &(&1 =~ "map-object"))
    refute Enum.any?(object_classes(view), &(&1 =~ "dimmed"))
  end

  test "dimming a layer dims the objects standing on it", %{view: view} do
    index = layer_of_first_object()

    :ok = Game.run_action([:map, :layer, :toggle_light], index)

    assert Enum.any?(object_classes(view), &(&1 =~ "dimmed"))
  end

  test "highlighting a layer highlights the objects standing on it", %{view: view} do
    index = layer_of_first_object()

    :ok = Game.run_action([:map, :layer, :toggle_highlight], index)

    assert Enum.any?(object_classes(view), &(&1 =~ "highlight"))
  end
end
