defmodule PathMapper.TestClient do
  @moduledoc """
  What the PathMapper client does, written in Elixir so tests can do it.

  A session is a directory of pieces. Each file is stored under the name its
  bytes hash to and declared as the entity its extension says it is, with the id
  its filename carries. The order is the directory's, because nothing depends on
  one: a reference resolves when it is read, so a token may arrive before or
  after whatever names it.

  It is a specification as much as a helper. Anything this does, the real client
  has to do too — which is why it reads the same `.pm*` extensions a game master
  would hand over, and why there is no archive and no manifest anywhere in it.

  A character is the one piece that is not a file: four fields and no bytes. The
  suite declares those itself, in `PathMapperWeb.TestHelpers`.
  """

  alias PathMapper.Id
  alias PathMapper.UploadStorage

  @sessions "test/data/sessions"

  @doc "The commands a directory of pieces becomes."
  def session_commands(name) do
    directory = Path.join(@sessions, name)

    directory
    |> File.ls!()
    |> Enum.sort()
    |> Enum.map(&piece(directory, &1))
  end

  defp piece(directory, filename) do
    bytes = File.read!(Path.join(directory, filename))

    filename |> Path.extname() |> declare(filename, bytes)
  end

  defp declare(".pmmap", filename, bytes) do
    %{
      "kind" => "map",
      "id" => Id.of(filename),
      "file" => store(bytes, "ora"),
      "name" => derived_name(filename)
    }
  end

  # A token says what it is in its own PNG, which is why a token needs no
  # manifest entry and never did.
  defp declare(".pmtoken", filename, bytes) do
    described = comment(bytes)

    %{
      "kind" => "token",
      "id" => Id.of(filename),
      "name" => described["name"] || derived_name(filename),
      "owner" => described["owner"] || "npc",
      "size" => described["size"] || 1,
      "image" => store(bytes, "png")
    }
  end

  # An archive holding one image, which is what the client unpacks.
  defp declare(".pmwallpaper", filename, bytes) do
    %{"kind" => "wallpaper", "id" => Id.of(filename), "file" => store(single_image(bytes), "png")}
  end

  defp single_image(bytes) do
    {:ok, entries} = :zip.unzip(bytes, [:memory])

    {_name, image} =
      Enum.find(entries, fn {name, _bytes} -> Path.extname(to_string(name)) == ".png" end)

    image
  end

  # A token says what it is in one PNG `Comment` chunk, a pipe-separated list of
  # `key: value` settings - one property rather than one per setting, because
  # one is what an image editor offers on the way out. The client's own
  # PathMapper::Token is the specification; this has to agree with it, or the
  # two sides of the pipeline are held to two oracles instead of one.
  #
  # A PNG is a signature then a run of length-type-data-crc chunks; a tEXt
  # chunk's data is a keyword, a zero byte, and the text.
  defp comment(<<_signature::binary-size(8), chunks::binary>>) do
    chunks |> chunks(%{}) |> Elixir.Map.get("Comment", "") |> settings()
  end

  defp comment(_other), do: %{}

  defp settings(text) do
    text
    |> String.split("|")
    |> Enum.flat_map(fn part ->
      case String.split(part, ":", parts: 2) do
        [key, value] -> [{key |> String.trim() |> String.downcase(), String.trim(value)}]
        _ -> []
      end
    end)
    |> Elixir.Map.new()
    |> then(&Elixir.Map.update(&1, "size", nil, fn size -> cast("size", size) end))
  end

  defp chunks(<<length::32, "tEXt", data::binary-size(length), _crc::32, rest::binary>>, found) do
    case :binary.split(data, <<0>>) do
      [keyword, text] -> chunks(rest, Elixir.Map.put(found, keyword, text))
      _ -> chunks(rest, found)
    end
  end

  defp chunks(
         <<length::32, _type::binary-size(4), _data::binary-size(length), _crc::32,
           rest::binary>>,
         found
       ),
       do: chunks(rest, found)

  defp chunks(_remainder, found), do: found

  defp cast("size", text) do
    case Integer.parse(text) do
      {size, _rest} -> size
      :error -> nil
    end
  end

  defp cast(_keyword, text), do: text

  defp store(bytes, extension) do
    {:ok, stored} = UploadStorage.store(bytes, extension)
    stored
  end

  # What is left of a filename once the id is taken off it, which is the only
  # name a piece gets unless it carries one of its own.
  defp derived_name(file) do
    case file |> Path.basename() |> Id.parse() do
      {:ok, _id, rest} -> rest |> String.replace("-", " ") |> String.trim()
      _ -> nil
    end
  end
end
