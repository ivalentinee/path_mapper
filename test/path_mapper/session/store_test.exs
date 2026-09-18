defmodule PathMapper.Session.StoreTest do
  use ExUnit.Case

  import PathMapperWeb.TestHelpers

  alias PathMapper.Adventures
  alias PathMapper.Game
  alias PathMapper.Session.Commands
  alias PathMapper.Session.Entity
  alias PathMapper.Session.Store
  alias PathMapper.TestClient

  @adventure "test/data/adventures/tt0001-0000000001-adventure-1.zip"

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

    test "refuses an id that holds another kind" do
      {:ok, _} = Store.put(token("tk0001-0000000001"))

      {:ok, scene} =
        Entity.build("scene", %{"id" => "tk0001-0000000001", "name" => "Clash", "order" => 0})

      assert {:error, message} = Store.put(scene)
      assert message =~ "is a token, not a scene"
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

  describe "hydrating an adventure" do
    setup do
      apply_commands(TestClient.adventure_commands(@adventure))
      :ok
    end

    test "the commands make an adventure the server can report" do
      assert {:ok, adventure} = Adventures.get_loaded()
      assert adventure.title == "Adventure example"
      assert adventure.id == "tt0001-0000000001"
    end

    test "its scenes arrive as entities of their own" do
      assert length(Store.of_kind("scene")) == 2
    end

    test "its maps and tokens arrive as entities of their own" do
      assert Store.of_kind("map") != []
      assert length(Store.of_kind("token")) == 2
    end

    test "a scene names its map and tokens rather than holding them" do
      scene = Store.of_kind("scene") |> Enum.min_by(& &1.data.order)

      assert is_binary(scene.data.map_id)
      assert Enum.all?(scene.data.tokens, &is_binary(&1.id))
    end

    test "game state follows the store" do
      assert length(Game.get_state().scene_list) == 2
    end

    test "a scene the store loses leaves game state" do
      [first | _] = Store.of_kind("scene")
      :ok = Commands.remove(first.id)

      refute Enum.any?(Game.get_state().scene_list, &(&1.id == first.id))
    end

    test "a scene made at the table continues the series" do
      {:ok, created} = Commands.create_scene("Ambush")

      assert created.id == "st0001-0000000003"
    end
  end

  describe "a scene made at the table" do
    test "is refused an empty name" do
      assert {:error, _} = Commands.create_scene("   ")
    end

    test "is refused a name another scene has" do
      {:ok, _} = Commands.create_scene("Ambush")

      assert {:error, message} = Commands.create_scene("Ambush")
      assert message =~ "already exists"
    end
  end
end
