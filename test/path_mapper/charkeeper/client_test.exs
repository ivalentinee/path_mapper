defmodule PathMapper.Charkeeper.ClientTest do
  use ExUnit.Case, async: false

  alias PathMapper.Charkeeper.CharacterData
  alias PathMapper.Charkeeper.Client

  setup_all do
    {:ok, _pid} =
      Bandit.start_link(plug: PathMapper.FakeCharkeeper, port: 0, ip: :loopback)
      |> case do
        {:ok, pid} ->
          {:ok, {_ip, port}} = ThousandIsland.listener_info(pid)
          {:ok, port: port}
      end
  end

  setup %{port: port} do
    server = "http://localhost:#{port}"
    {:ok, server: server}
  end

  test "fetches and parses character data", %{server: server} do
    assert {:ok, %CharacterData{} = data} = Client.fetch(server, "test-uuid-1")
    assert data.name == "Test Hero"
    assert data.class == "Fighter"
    assert data.level == 3
    assert data.ancestry == "Human"
    assert data.hp_current == 10
    assert data.hp_temp == 2
    assert data.hp_max == 15
    assert data.armor_class == 18
  end

  test "returns error for unknown character", %{server: server} do
    assert {:error, {:http_status, 404}} = Client.fetch(server, "nonexistent")
  end

  test "handles second character", %{server: server} do
    assert {:ok, %CharacterData{} = data} = Client.fetch(server, "test-uuid-2")
    assert data.name == "Test Mage"
    assert data.class == "Wizard"
    assert data.hp_current == 6
    assert data.hp_temp == 0
  end
end
