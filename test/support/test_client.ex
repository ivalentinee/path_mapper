defmodule PathMapper.TestClient do
  @moduledoc """
  What the PathMapper client does, written in Elixir so tests can do it.

  Unpacks a blob, stores each asset under the name its bytes hash to, and turns the
  manifest into the sequence of commands the server now takes. There is no
  description any more: an adventure is a declaration of the adventure, one of each
  scene, and one of every map and token those scenes name.

  It is a specification as much as a helper. Anything this does, the real client has
  to do too.
  """

  alias PathMapper.Id
  alias PathMapper.UploadStorage

  @manifest "manifest.toml"

  @doc "The commands an adventure blob becomes, in the order they must be sent."
  def adventure_commands(path) do
    {manifest, stored} = unpack(path)

    scenes = Elixir.Map.get(manifest, "scenes", [])

    [adventure(manifest, path)] ++
      Enum.flat_map(Enum.with_index(scenes), fn {scene, order} ->
        scene_commands(scene, order, stored)
      end)
  end

  @doc "The commands a group blob becomes."
  def group_commands(path) do
    {manifest, stored} = unpack(path)

    players = manifest |> Elixir.Map.get("players", []) |> Enum.map(&player(&1, stored))

    token_commands =
      manifest
      |> Elixir.Map.get("players", [])
      |> Enum.flat_map(&player_tokens(&1, stored))

    token_commands ++
      [
        %{
          "kind" => "group",
          "id" => Id.of(path),
          "title" => manifest["title"],
          "file" => Path.basename(path),
          "players" => players
        }
      ]
  end

  defp adventure(manifest, path) do
    %{
      "kind" => "adventure",
      "id" => Id.of(path),
      "title" => manifest["title"],
      "file" => Path.basename(path),
      "wallpaper" => stored_or_nil(manifest["wallpaper"], path),
      "urls" => manifest["urls"] || []
    }
  end

  # A map and every token a scene names are entities in their own right, declared
  # before the scene that refers to them.
  defp scene_commands(scene, order, stored) do
    map = scene["map"]
    map_name = map && map["file"]
    map_id = map_name && Id.of(map_name)

    tokens = Elixir.Map.get(scene, "tokens", [])

    map_commands(map_id, map_name, stored) ++
      Enum.map(tokens, &token(&1, stored)) ++
      [
        %{
          "kind" => "scene",
          "id" => scene["id"],
          "ref" => scene["ref"],
          "name" => scene["name"],
          "type" => scene["type"],
          "order" => order,
          "map_id" => map_id,
          "tokens" => Enum.map(tokens, fn t -> %{"id" => Id.of(t["image"])} end),
          "place_tokens" => Elixir.Map.get(scene, "place_tokens", [])
        }
      ]
  end

  defp map_commands(nil, _name, _stored), do: []

  defp map_commands(id, name, stored) do
    [%{"kind" => "map", "id" => id, "file" => Elixir.Map.fetch!(stored, name)}]
  end

  defp token(token, stored) do
    %{
      "kind" => "token",
      "id" => Id.of(token["image"]),
      "name" => token["name"],
      "owner" => token["owner"] || "npc",
      "size" => token["size"],
      "image" => Elixir.Map.fetch!(stored, token["image"])
    }
  end

  defp player_tokens(player, stored) do
    extras = Elixir.Map.get(player, "extra_tokens", [])

    [
      %{
        "kind" => "token",
        "id" => Id.of(player["token"]),
        "name" => player["character_name"],
        "owner" => "npc",
        "size" => 1,
        "image" => Elixir.Map.fetch!(stored, player["token"])
      }
      | Enum.map(extras, fn extra ->
          %{
            "kind" => "token",
            "id" => Id.of(extra["image"]),
            "name" => extra["name"],
            "owner" => "npc",
            "size" => 1,
            "image" => Elixir.Map.fetch!(stored, extra["image"])
          }
        end)
    ]
  end

  defp player(player, stored) do
    player
    |> Elixir.Map.put("token_id", Id.of(player["token"]))
    |> Elixir.Map.put("token", Elixir.Map.fetch!(stored, player["token"]))
    |> Elixir.Map.update("extra_tokens", [], fn extras ->
      Enum.map(extras, fn extra ->
        extra
        |> Elixir.Map.put("id", Id.of(extra["image"]))
        |> Elixir.Map.put("image", Elixir.Map.fetch!(stored, extra["image"]))
      end)
    end)
  end

  defp stored_or_nil(nil, _path), do: nil

  defp stored_or_nil(name, path) do
    {_manifest, stored} = unpack(path)
    Elixir.Map.get(stored, name)
  end

  # The client unzips; the server never sees an archive.
  defp unpack(path) do
    {:ok, entries} = :zip.unzip(String.to_charlist(path), [:memory])
    files = Elixir.Map.new(entries, fn {name, bytes} -> {to_string(name), bytes} end)

    {:ok, manifest} = :tomerl.parse(Elixir.Map.fetch!(files, @manifest))

    :ok = UploadStorage.initialize()

    stored =
      files
      |> Elixir.Map.delete(@manifest)
      |> Elixir.Map.new(fn {name, bytes} ->
        {:ok, stored} = UploadStorage.store(bytes, extension(name))
        {name, stored}
      end)

    {manifest, stored}
  end

  defp extension(name), do: name |> Path.extname() |> String.trim_leading(".")
end
