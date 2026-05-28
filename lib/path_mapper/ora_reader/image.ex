defmodule PathMapper.ORAReader.Image do
  def png_dimensions(
        <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, _length::32, "IHDR", width::32,
          height::32, _rest::binary>>
      ) do
    {:ok, {width, height}}
  end

  def png_dimensions(_), do: {:error, :invalid_png}
end
