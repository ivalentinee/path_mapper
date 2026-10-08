defmodule PathMapper.ORAReaderTest do
  use ExUnit.Case

  alias PathMapper.ORAReader

  test "parses bracket prefix layer convention" do
    {:ok, result} =
      ORAReader.read_from_file(
        File.read!("test/data/sessions/standard/mt0001-0000000001-scene-1.pmmap")
      )

    assert length(result.layers) == 4
    assert Enum.map(result.layers, & &1.index) == [1, 2, 3, 4]
  end

  test "parses grid and fow layers" do
    {:ok, result} =
      ORAReader.read_from_file(
        File.read!("test/data/sessions/standard/mt0001-0000000001-scene-1.pmmap")
      )

    assert result.grid != nil
    assert result.grid.name == "Grid"
    assert result.fow != nil
    assert result.fow.name == "FOW"
  end

  test "parses map objects from layer groups" do
    {:ok, result} =
      ORAReader.read_from_file(
        File.read!("test/data/sessions/standard/mt0001-0000000001-scene-1.pmmap")
      )

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
    {:ok, result} =
      ORAReader.read_from_file(
        File.read!("test/data/sessions/standard/mt0001-0000000001-scene-1.pmmap")
      )

    first_layer = Enum.find(result.layers, &(&1.index == 1))
    assert first_layer.width == 100
    assert first_layer.height == 100
  end

  test "parses suffix tags in separate brackets" do
    {:ok, result} =
      ORAReader.read_from_file(
        File.read!("test/data/sessions/standard/mt0001-0000000001-scene-1.pmmap")
      )

    layer_3 = Enum.find(result.layers, &(&1.index == 3))
    assert "hide" in layer_3.tags
    assert "floor-1" in layer_3.tags
  end

  describe "the metadata layer" do
    test "gives the map its name and its url" do
      {:ok, result} = read("mt0001-0000000002-scene-2.pmmap")

      assert result.name == "Крепость Чёрного Камня"
      assert result.url == "https://example.com/keep?a=1&b=2"
    end

    # Nothing has to remember to skip it: a metadata item carries no image, so
    # none of the three selectors that feed a rendering can pick it up.
    test "is drawn by nothing" do
      {:ok, with_one} = read("mt0001-0000000002-scene-2.pmmap")
      {:ok, without} = read("mt0001-0000000001-scene-1.pmmap")

      assert length(with_one.layers) == length(without.layers)
      assert Enum.all?(with_one.layers, &(&1.name != "Крепость Чёрного Камня"))
      assert Enum.all?(with_one.map_objects, &(&1.name != "Крепость Чёрного Камня"))
      refute with_one.grid.name == "Крепость Чёрного Камня"
    end

    test "a map declaring none has neither" do
      {:ok, result} = read("mt0001-0000000001-scene-1.pmmap")

      assert result.name == nil
      assert result.url == nil
    end
  end

  # OpenRaster positions a stack's children relative to the stack itself. Every
  # fixture here is hand-written and gives its groups no offset, so until a map
  # came from GIMP with one, reading a child's x/y as absolute was right by
  # accident. Built in the test rather than added as a binary, because the point
  # is the one attribute pair and a .pmmap hides it.
  describe "a group that carries an offset" do
    test "positions what is inside it relative to the group" do
      {:ok, result} = read_built(group_offset: {1220, 32}, object_at: {126, 167})

      object = hd(result.map_objects)

      assert {object.x, object.y} == {1346, 199}
    end

    test "leaves a group at the origin where it is" do
      {:ok, result} = read_built(group_offset: {0, 0}, object_at: {1010, 1414})

      object = hd(result.map_objects)

      assert {object.x, object.y} == {1010, 1414}
    end

    # What every fixture in this file says, and what the reader assumed of all
    # of them.
    test "a group with no offset at all is a group at the origin" do
      {:ok, result} = read_built(group_offset: nil, object_at: {30, 40})

      object = hd(result.map_objects)

      assert {object.x, object.y} == {30, 40}
    end

    test "moves the base image under the objects by the same amount" do
      {:ok, result} = read_built(group_offset: {100, 200}, object_at: {10, 20})

      layer = hd(result.layers)

      assert {layer.x, layer.y} == {100, 200}
      assert [%{x: 100, y: 200}] = layer.images
    end
  end

  defp read_built(options) do
    {ox, oy} = Keyword.fetch!(options, :object_at)

    offset =
      case Keyword.fetch!(options, :group_offset) do
        nil -> ""
        {gx, gy} -> ~s( x="#{gx}" y="#{gy}")
      end

    stack = """
    <?xml version='1.0' encoding='UTF-8'?>
    <image w="2099" h="1553"><stack>
      <stack name="[L1] Hall"#{offset}>
        <layer src="data/object.png" name="Door [link mt0001-0000000002]" x="#{ox}" y="#{oy}"/>
        <layer src="data/base.png" name="[B] Hall" x="0" y="0"/>
      </stack>
    </stack></image>
    """

    files = [
      {~c"mimetype", "image/openraster"},
      {~c"stack.xml", stack},
      {~c"data/object.png", png(292, 58)},
      {~c"data/base.png", png(2099, 1553)}
    ]

    {:ok, {_name, bytes}} = :zip.create(~c"built.ora", files, [:memory])

    ORAReader.read_from_file(bytes)
  end

  # Only the IHDR is read, so the pixels are never needed.
  defp png(width, height) do
    chunk = fn type, data ->
      <<byte_size(data)::32>> <> type <> data <> <<:erlang.crc32(type <> data)::32>>
    end

    <<137, 80, 78, 71, 13, 10, 26, 10>> <>
      chunk.("IHDR", <<width::32, height::32, 8, 6, 0, 0, 0>>) <> chunk.("IEND", "")
  end

  defp read(name),
    do: ORAReader.read_from_file(File.read!("test/data/sessions/standard/#{name}"))
end
