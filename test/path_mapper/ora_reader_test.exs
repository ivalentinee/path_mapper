defmodule PathMapper.ORAReaderTest do
  use ExUnit.Case

  alias PathMapper.ORAReader

  test "parses bracket prefix layer convention" do
    {:ok, result} = ORAReader.read_from_file(File.read!("test/data/adventures/unpacked/map.ora"))

    assert length(result.layers) == 4
    assert Enum.map(result.layers, & &1.index) == [1, 2, 3, 4]
  end

  test "parses grid and fow layers" do
    {:ok, result} = ORAReader.read_from_file(File.read!("test/data/adventures/unpacked/map.ora"))

    assert result.grid != nil
    assert result.grid.name == "Grid"
    assert result.fow != nil
    assert result.fow.name == "FOW"
  end

  test "parses map objects from layer groups" do
    {:ok, result} = ORAReader.read_from_file(File.read!("test/data/adventures/unpacked/map.ora"))

    assert length(result.map_objects) == 2

    table = Enum.find(result.map_objects, &(&1.name == "Table"))
    assert table.layer_index == 1
    assert table.x == 30
    assert table.y == 40
    assert table.width == 20
    assert table.height == 20

    barrel = Enum.find(result.map_objects, &(&1.name == "Barrel"))
    assert barrel.layer_index == 1
    assert barrel.x == 50
    assert barrel.y == 60
  end

  test "extracts layer dimensions from PNG headers" do
    {:ok, result} = ORAReader.read_from_file(File.read!("test/data/adventures/unpacked/map.ora"))

    first_layer = Enum.find(result.layers, &(&1.index == 1))
    assert first_layer.width == 100
    assert first_layer.height == 100
  end

  test "parses suffix tags in separate brackets" do
    {:ok, result} = ORAReader.read_from_file(File.read!("test/data/adventures/unpacked/map.ora"))

    layer_3 = Enum.find(result.layers, &(&1.index == 3))
    assert "hide" in layer_3.tags
    assert "floor-1" in layer_3.tags
  end
end
