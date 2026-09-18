defmodule PathMapper.Game.SnapshotTest do
  use ExUnit.Case

  alias PathMapper.Game.Snapshot
  alias PathMapper.UploadStorage

  defp unpacked(path), do: Path.join([:code.priv_dir(:path_mapper), "unpacked", path])

  defp stored_asset(bytes) do
    :ok = UploadStorage.initialize()
    {:ok, path} = UploadStorage.store_image(bytes)
    path
  end

  defp manifest_referencing(paths) do
    %{
      "version" => 3,
      "adventure_id" => "tt0001-0000000001",
      "scenes" => %{
        "0" => %{
          "custom" => true,
          "custom_map" => %{
            "layers" => Enum.map(paths, &%{"image" => &1})
          }
        }
      }
    }
  end

  test "an archive carries the assets its manifest references" do
    path = stored_asset("first-layer-bytes")
    {:ok, archive} = Snapshot.pack(manifest_referencing([path]))

    {:ok, entries} = :zip.unzip(archive, [:memory])
    names = Enum.map(entries, fn {name, _} -> to_string(name) end)

    assert "manifest.json" in names
    assert "assets/#{Path.basename(path)}" in names
  end

  test "unpacking writes an asset back to the path the manifest records" do
    path = stored_asset("layer-bytes-for-round-trip")
    {:ok, archive} = Snapshot.pack(manifest_referencing([path]))

    File.rm!(unpacked(path))
    refute File.exists?(unpacked(path))

    {:ok, manifest} = Snapshot.unpack(archive)

    assert File.exists?(unpacked(path))
    assert File.read!(unpacked(path)) == "layer-bytes-for-round-trip"
    assert get_in(manifest, ["scenes", "0", "custom_map", "layers"]) == [%{"image" => path}]
  end

  test "an asset the store no longer holds is left out, and the archive still packs" do
    kept = stored_asset("kept-bytes")
    gone = stored_asset("gone-bytes")
    File.rm!(unpacked(gone))

    {:ok, archive} = Snapshot.pack(manifest_referencing([kept, gone]))
    {:ok, entries} = :zip.unzip(archive, [:memory])
    names = Enum.map(entries, fn {name, _} -> to_string(name) end)

    assert "assets/#{Path.basename(kept)}" in names
    refute "assets/#{Path.basename(gone)}" in names
  end

  test "a manifest with no assets still round-trips" do
    {:ok, archive} = Snapshot.pack(manifest_referencing([]))
    assert {:ok, %{"version" => 3}} = Snapshot.unpack(archive)
  end

  test "an archive without a manifest is refused" do
    {:ok, {_name, archive}} = :zip.create(~c"x.zip", [{~c"other.txt", "hi"}], [:memory])
    assert {:error, "Snapshot holds no manifest.json"} = Snapshot.unpack(archive)
  end

  test "something that is not an archive is refused" do
    assert {:error, "Snapshot is not a readable archive"} = Snapshot.unpack("not a zip")
  end
end
