defmodule PathMapper.MapTools.HitTestTest do
  use ExUnit.Case, async: true

  alias PathMapper.Game.State.Scene.DrawnElement
  alias PathMapper.MapTools.HitTest

  # grid_size = 50 (map pixels), subpixel_factor = 10
  # so grid_size_sp = 500, one cell = 500 subpixels
  @grid_size 50

  defp fill(x, y) do
    %DrawnElement{
      id: "fill-#{x}-#{y}",
      type: :fill,
      color: "#ff0000",
      owner: "GM",
      data: %{"x" => x, "y" => y}
    }
  end

  defp rect(x1, y1, x2, y2) do
    %DrawnElement{
      id: "rect",
      type: :rect,
      color: "#ff0000",
      owner: "GM",
      data: %{"x1" => x1, "y1" => y1, "x2" => x2, "y2" => y2}
    }
  end

  defp line(points) do
    %DrawnElement{
      id: "line",
      type: :line,
      color: "#ff0000",
      owner: "GM",
      data: %{"points" => points, "width" => 2}
    }
  end

  defp circle(cx, cy, r) do
    %DrawnElement{
      id: "circle",
      type: :circle,
      color: "#ff0000",
      owner: "GM",
      data: %{"cx" => cx, "cy" => cy, "radius" => r}
    }
  end

  describe "fill hit-test" do
    test "click inside cell hits" do
      assert %{id: "fill-2-3"} = HitTest.find([fill(2, 3)], 1050, 1550, @grid_size)
    end

    test "click outside cell misses" do
      assert nil == HitTest.find([fill(2, 3)], 50, 50, @grid_size)
    end
  end

  describe "rect hit-test" do
    test "click inside rect hits" do
      assert %{id: "rect"} = HitTest.find([rect(1, 1, 3, 3)], 1000, 1000, @grid_size)
    end

    test "click outside rect misses" do
      assert nil == HitTest.find([rect(1, 1, 3, 3)], 50, 50, @grid_size)
    end
  end

  describe "line hit-test" do
    test "click near line segment hits" do
      # Line from (100, 100) to (200, 100) in map pixels
      # Click at (150, 100) in map pixels = (1500, 1000) in subpixels
      assert %{id: "line"} =
               HitTest.find([line([[100, 100], [200, 100]])], 1500, 1000, @grid_size)
    end

    test "click far from line misses" do
      assert nil == HitTest.find([line([[100, 100], [200, 100]])], 1500, 5000, @grid_size)
    end
  end

  describe "circle hit-test" do
    test "click on perimeter hits" do
      # Circle at (200, 200) radius 50 in map pixels
      # Click at (250, 200) = perimeter = (2500, 2000) in subpixels
      assert %{id: "circle"} = HitTest.find([circle(200, 200, 50)], 2500, 2000, @grid_size)
    end

    test "click at center misses (perimeter-only)" do
      assert nil == HitTest.find([circle(200, 200, 50)], 2000, 2000, @grid_size)
    end
  end

  describe "layering" do
    test "topmost element (newest) is hit first" do
      elements = [fill(2, 3), fill(2, 3)]
      [first, second] = elements
      result = HitTest.find(elements, 1050, 1550, @grid_size)
      assert result.id == second.id
    end
  end
end
