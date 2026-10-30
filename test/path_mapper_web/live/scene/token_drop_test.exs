defmodule PathMapperWeb.Scene.TokenDropTest do
  @moduledoc """
  Where a dragged token lands.

  The drop used to commit whatever the last `drag` event had told the server,
  which is however far behind the pointer the round trip had got to. The token
  settled short of where it was let go, and the correction was visible.
  """
  use PathMapperWeb.ConnCase
  import Phoenix.LiveViewTest

  alias PathMapper.Game
  alias PathMapper.Geometry.Mapper, as: GeometryMapper

  # The standard fixture's map is [grid-10].
  @grid 10

  setup %{conn: conn} do
    load_session()
    :ok = select_surface(1)

    :ok = Game.run_action([:tokens, :add], "tk0001-0000000001")

    {:ok, view, _html} = live(conn, "/master")
    view |> element("#scene") |> render_hook("geometry", %{"width" => 1600, "height" => 1000})

    {:ok, %{view: view, game_id: placed_game_id()}}
  end

  defp placed_game_id, do: hd(Game.get_state().surface.tokens).game_id

  defp token_element(view), do: element(view, ".tokens-container [phx-hook='Draggable']")

  defp at(game_id), do: placement(game_id) |> then(&{unit(&1.x), unit(&1.y)})

  # Where the drag has reached, which is held apart from the committed
  # position until the drop commits one of them.
  defp dragging_at(game_id),
    do: placement(game_id) |> then(&{unit(&1.drag_x), unit(&1.drag_y)})

  defp placement(game_id),
    do: Enum.find(Game.get_state().surface.tokens, &(&1.game_id == game_id))

  defp unit(nil), do: nil
  defp unit(value), do: GeometryMapper.from_subpixels(value)

  # The drop snaps to the grid, so a committed position is the dragged one
  # rounded, never equal to it.
  defp near?({x, y}, {to_x, to_y}, grid), do: abs(x - to_x) <= grid and abs(y - to_y) <= grid

  defp drag_from(view, {x, y}) do
    token = token_element(view)
    render_hook(token, "dragstart", %{"x" => x, "y" => y})
    token
  end

  test "lands where it was let go, not where the last drag reached", %{view: view, game_id: id} do
    token = drag_from(view, {400, 300})

    # the pointer gets ahead of the server: one drag lands, then the drop
    render_hook(token, "drag", %{"x" => 500, "y" => 300, "id" => "token-0"})
    reached = dragging_at(id)

    render_hook(token, "dragend", %{"x" => 900, "y" => 700, "id" => "token-0"})

    refute near?(at(id), reached, @grid)
    assert elem(at(id), 0) > elem(reached, 0)
    assert elem(at(id), 1) > elem(reached, 1)
  end

  # A browser that sends no coordinates with the drop still has the last drag
  # the server was told about, which is where it used to land every time.
  test "falls back to the last drag when the drop says nothing", %{view: view, game_id: id} do
    token = drag_from(view, {400, 300})

    render_hook(token, "drag", %{"x" => 500, "y" => 320, "id" => "token-0"})
    reached = dragging_at(id)

    render_hook(token, "dragend", %{"id" => "token-0"})

    assert near?(at(id), reached, @grid)
  end
end
