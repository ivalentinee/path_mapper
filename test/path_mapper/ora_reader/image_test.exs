defmodule PathMapper.ORAReader.ImageTest do
  use ExUnit.Case

  alias PathMapper.ORAReader.Image

  test "extracts dimensions from valid PNG" do
    # Minimal PNG: 8-byte signature + 4-byte length + "IHDR" + 4-byte width + 4-byte height
    png =
      <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, "IHDR", 0x00,
        0x00, 0x00, 0x40, 0x00, 0x00, 0x00, 0x30, 0x08, 0x02, 0x00, 0x00, 0x00>>

    assert {:ok, {64, 48}} = Image.png_dimensions(png)
  end

  test "returns error for non-PNG data" do
    assert {:error, :invalid_png} = Image.png_dimensions("not a png")
  end

  test "returns error for truncated PNG" do
    assert {:error, :invalid_png} = Image.png_dimensions(<<0x89, 0x50, 0x4E>>)
  end
end
