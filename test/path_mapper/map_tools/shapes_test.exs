defmodule PathMapper.MapTools.ShapesTest do
  use ExUnit.Case, async: true

  alias PathMapper.MapTools.Shapes

  # All coordinates in subpixel units (map pixels * 10)
  @grid_size 500
  @factor 10

  defp sp(map_pixels), do: round(map_pixels * @factor)

  describe "compute/2 — shape mode" do
    test "ruler returns origin, length, angle, and distance" do
      tool_data = tool("ruler", "shape", sp(0), sp(0), sp(150), sp(0), distance: "15.0ft")
      result = Shapes.compute(tool_data, @grid_size)

      assert result.type == :ruler
      assert result.sx == 0
      assert result.sy == 0
      assert result.length == sp(150)
      assert result.angle == 0.0
      assert result.distance == "15.0ft"
      assert result.text_x == sp(75)
    end

    test "ruler at 45 degrees computes correct angle" do
      tool_data = tool("ruler", "shape", sp(0), sp(0), sp(100), sp(100))
      result = Shapes.compute(tool_data, @grid_size)

      assert_in_delta result.angle, 45.0, 0.1
    end

    test "pointer returns cursor position" do
      tool_data = tool("pointer", "shape", sp(0), sp(0), sp(100), sp(200))
      result = Shapes.compute(tool_data, @grid_size)

      assert result.type == :pointer
      assert result.cx == sp(100)
      assert result.cy == sp(200)
    end

    test "burst returns circle centered on origin" do
      tool_data = tool("burst", "shape", sp(100), sp(100), sp(200), sp(100))
      result = Shapes.compute(tool_data, @grid_size)

      assert result.type == :circle
      assert result.cx == sp(100)
      assert result.cy == sp(100)
      assert result.r == sp(100)
    end

    test "emanation returns circle" do
      tool_data = tool("emanation", "shape", sp(75), sp(75), sp(175), sp(75))
      result = Shapes.compute(tool_data, @grid_size)

      assert result.type == :circle
      assert result.r == sp(100)
    end

    test "cone returns arc coordinates and radius" do
      tool_data = tool("cone", "shape", sp(0), sp(0), sp(100), sp(0))
      result = Shapes.compute(tool_data, @grid_size)

      assert result.type == :cone
      assert result.sx == 0
      assert result.sy == 0
      assert result.radius == sp(100)
      # All returned values are integers (subpixels)
      assert is_integer(result.x1)
      assert is_integer(result.y1)
      assert is_integer(result.x2)
      assert is_integer(result.y2)
    end

    test "cone pointing down" do
      tool_data = tool("cone", "shape", sp(0), sp(0), sp(0), sp(100))
      result = Shapes.compute(tool_data, @grid_size)

      assert result.type == :cone
      assert result.radius == sp(100)
    end

    test "line returns 4 integer corners" do
      tool_data = tool("line", "shape", sp(0), sp(0), sp(100), sp(0))
      result = Shapes.compute(tool_data, @grid_size)

      assert result.type == :line
      assert length(result.corners) == 4
      # All corners are integer tuples
      for {x, y} <- result.corners do
        assert is_integer(x)
        assert is_integer(y)
      end
    end

    test "unknown tool returns :none" do
      tool_data = tool("unknown", "shape", sp(0), sp(0), sp(100), sp(100))
      result = Shapes.compute(tool_data, @grid_size)

      assert result.type == :none
    end
  end

  describe "compute/2 — grid mode" do
    test "burst grid produces cells within radius" do
      tool_data = tool("burst", "grid", sp(100), sp(100), sp(200), sp(100))
      result = Shapes.compute(tool_data, @grid_size)

      assert result.type == :grid_cells
      assert length(result.cells) > 0
      assert result.cell_size == @grid_size
    end

    test "burst grid with zero radius returns empty cells" do
      tool_data = tool("burst", "grid", sp(100), sp(100), sp(100), sp(100))
      result = Shapes.compute(tool_data, @grid_size)

      assert result.type == :grid_cells
      assert result.cells == []
    end

    test "cone grid produces cells" do
      tool_data = tool("cone", "grid", sp(0), sp(0), sp(150), sp(0))
      result = Shapes.compute(tool_data, @grid_size)

      assert result.type == :grid_cells
      assert length(result.cells) > 0
    end

    test "line grid produces cells" do
      tool_data = tool("line", "grid", sp(0), sp(25), sp(200), sp(25))
      result = Shapes.compute(tool_data, @grid_size)

      assert result.type == :grid_cells
      assert length(result.cells) > 0
    end

    test "grid mode with pointer returns empty cells" do
      tool_data = tool("pointer", "grid", sp(0), sp(0), sp(100), sp(100))
      result = Shapes.compute(tool_data, @grid_size)

      assert result.type == :grid_cells
      assert result.cells == []
    end
  end

  describe "compute/2 — ruler path" do
    test "single waypoint with pending point produces one segment" do
      tool_data = path_tool([{sp(0), sp(0)}], sp(100), sp(0))
      result = Shapes.compute(tool_data, @grid_size)

      assert result.type == :ruler_path
      assert length(result.segments) == 1
      [seg] = result.segments
      assert seg.sx == sp(0)
      assert seg.sy == sp(0)
      assert seg.length == sp(100)
      assert seg.feet == 10.0
    end

    test "two waypoints show cumulative distance" do
      # 100px horizontal + 100px vertical = 10ft + 10ft cumulative
      tool_data = path_tool([{sp(0), sp(0)}, {sp(100), sp(0)}], sp(100), sp(100))
      result = Shapes.compute(tool_data, @grid_size)

      assert length(result.segments) == 2
      [seg1, seg2] = result.segments
      assert seg1.feet == 10.0
      assert seg2.feet == 20.0
    end

    test "empty waypoints produces no segments" do
      tool_data = path_tool([], sp(100), sp(100))
      result = Shapes.compute(tool_data, @grid_size)

      assert result.type == :ruler_path
      assert result.segments == []
    end

    test "segments have integer coordinates" do
      tool_data = path_tool([{sp(0), sp(0)}, {sp(50), sp(50)}], sp(100), sp(50))
      result = Shapes.compute(tool_data, @grid_size)

      for seg <- result.segments do
        assert is_integer(seg.sx)
        assert is_integer(seg.sy)
        assert is_integer(seg.length)
        assert is_integer(seg.text_x)
        assert is_integer(seg.text_y)
      end
    end
  end

  describe "integer precision" do
    test "shape coordinates are integers" do
      tool_data = tool("burst", "shape", sp(33), sp(66), sp(133), sp(66))
      result = Shapes.compute(tool_data, @grid_size)

      assert is_integer(result.cx)
      assert is_integer(result.cy)
      assert is_integer(result.r)
    end

    test "handles nil coordinates gracefully" do
      tool_data = %{"tool" => "burst", "mode" => "shape"}
      result = Shapes.compute(tool_data, @grid_size)

      assert result.type == :circle
      assert result.cx == 0
      assert result.r == 0
    end
  end

  defp path_tool(waypoints, cx, cy, opts \\ []) do
    %{
      "tool" => "ruler",
      "mode" => "path",
      "waypoints" => waypoints,
      "current_x" => cx,
      "current_y" => cy,
      "grid_size" => @grid_size,
      "color" => "#db0909",
      "distance" => Keyword.get(opts, :distance)
    }
  end

  defp tool(name, mode, sx, sy, cx, cy, opts \\ []) do
    %{
      "tool" => name,
      "mode" => mode,
      "start_x" => sx,
      "start_y" => sy,
      "current_x" => cx,
      "current_y" => cy,
      "grid_size" => @grid_size,
      "color" => "#db0909",
      "distance" => Keyword.get(opts, :distance)
    }
  end
end
