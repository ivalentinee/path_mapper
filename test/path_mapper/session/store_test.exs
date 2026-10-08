defmodule PathMapper.Session.StoreTest do
  use ExUnit.Case

  import PathMapperWeb.TestHelpers

  alias PathMapper.Api.Document
  alias PathMapper.Game
  alias PathMapper.Session.Commands
  alias PathMapper.Session.Encode
  alias PathMapper.Session.Entity
  alias PathMapper.Session.Store
  alias PathMapper.TestClient

  setup do
    Game.clear()
    :ok
  end

  # A token names a stored asset and the schema checks it, so the bytes go in first.
  defp token(id, name \\ "Goblin") do
    :ok = PathMapper.UploadStorage.initialize()
    {:ok, image} = PathMapper.UploadStorage.store("token bytes", "png")

    {:ok, entity} =
      Entity.build("token", %{
        "id" => id,
        "name" => name,
        "owner" => "enemy",
        "size" => 1,
        "image" => image
      })

    entity
  end

  describe "put/1" do
    test "adds an entity under its id" do
      {:ok, _} = Store.put(token("tk0001-0000000001"))

      assert %Entity{kind: "token"} = Store.get("tk0001-0000000001")
    end

    # Ids are shared deliberately, so the same id arriving twice is the same thing
    # declared again rather than a collision.
    test "replaces an entity of the same kind" do
      {:ok, _} = Store.put(token("tk0001-0000000001", "Goblin"))
      {:ok, _} = Store.put(token("tk0001-0000000001", "Hobgoblin"))

      assert Store.get("tk0001-0000000001").data.name == "Hobgoblin"
    end
  end

  describe "remove" do
    test "takes an entity out" do
      {:ok, _} = Store.put(token("tk0001-0000000001"))
      :ok = Commands.remove("tk0001-0000000001")

      assert Store.get("tk0001-0000000001") == nil
    end

    test "removing what is not there is not an error" do
      assert :ok = Commands.remove("tk0001-0000009999")
    end
  end

  describe "hydrating a session" do
    setup do
      apply_commands(TestClient.session_commands("standard"))
      :ok
    end

    test "the pieces arrive, and nothing names a package" do
      assert Store.of_kind("map") != []
      assert Store.of_kind("wallpaper") != []
      assert Enum.all?(Store.all(), &(&1.kind in ~w(map token wallpaper character)))
    end

    test "its maps and tokens arrive as entities of their own" do
      assert Store.of_kind("map") != []
      assert length(Store.of_kind("token")) == 2
    end

    test "game state follows the store" do
      assert length(Game.get_state().surface_list) == 2
    end
  end

  describe "a scene made at the table" do
  end

  describe "what the store hands back" do
    setup do
      apply_commands(TestClient.session_commands("standard"))
      :ok
    end

    # Encode's own promise: "a client saves what it is given and replays it
    # unchanged". A dump carrying what the server derived - a map's layers, its
    # objects, its grid - was refused by the gate it came from.
    test "every entity it dumps is one it would accept back" do
      for entity <- Store.all() do
        command = Encode.command(entity)
        kind = command["kind"]

        assert {:ok, _rebuilt} = Entity.build(kind, Elixir.Map.delete(command, "kind")),
               "#{kind} #{entity.id} did not survive its own dump"

        assert Elixir.Map.keys(command) -- Document.declared_fields(kind) == [],
               "#{kind} #{entity.id} dumped fields the contract does not declare"
      end
    end

    test "and the declaration is still enough to rebuild it" do
      map = Store.all() |> Enum.find(&(&1.kind == "map"))
      command = Encode.command(map)

      {:ok, rebuilt} = Entity.build("map", Elixir.Map.delete(command, "kind"))

      assert rebuilt.data.width == map.data.width
      assert length(rebuilt.data.layers) == length(map.data.layers)
    end
  end
end
