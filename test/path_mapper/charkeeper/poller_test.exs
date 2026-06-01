defmodule PathMapper.Charkeeper.PollerTest do
  use ExUnit.Case, async: false

  alias PathMapper.Charkeeper
  alias PathMapper.Charkeeper.Poller

  setup_all do
    {:ok, pid} = Bandit.start_link(plug: PathMapper.FakeCharkeeper, port: 0, ip: :loopback)
    {:ok, {_ip, port}} = ThousandIsland.listener_info(pid)
    {:ok, port: port}
  end

  setup %{port: port} do
    server = "http://localhost:#{port}"
    Application.put_env(:path_mapper, :charkeeper_server, server)
    Application.put_env(:path_mapper, :charkeeper_poll_interval, 100)

    on_exit(fn ->
      Charkeeper.stop()
      Application.delete_env(:path_mapper, :charkeeper_server)
      Application.delete_env(:path_mapper, :charkeeper_poll_interval)
    end)

    :ok
  end

  test "poller fetches data and makes it available via get_data" do
    ids = [{"Test Hero", "test-uuid-1"}, {"Test Mage", "test-uuid-2"}]

    {:ok, _pid} =
      DynamicSupervisor.start_child(Charkeeper.Supervisor, {Poller, ids})

    # Wait for first poll
    Process.sleep(300)

    %{data: data, status: status} = Charkeeper.get_data()
    assert status == :ok
    assert map_size(data) == 2
    assert data["Test Hero"].class == "Fighter"
    assert data["Test Mage"].class == "Wizard"
  end

  test "poller reports partial status when some fetches fail" do
    ids = [{"Test Hero", "test-uuid-1"}, {"Ghost", "nonexistent-uuid"}]

    {:ok, _pid} =
      DynamicSupervisor.start_child(Charkeeper.Supervisor, {Poller, ids})

    Process.sleep(300)

    %{data: data, status: status} = Charkeeper.get_data()
    assert status == :partial
    assert map_size(data) == 1
    assert data["Test Hero"].class == "Fighter"
  end

  test "start_or_restart starts and stops poller" do
    players = [
      %{character_name: "Test Hero", charkeeper_id: "test-uuid-1"},
      %{character_name: "No CK", charkeeper_id: nil}
    ]

    Charkeeper.start_or_restart(players)
    assert Poller.whereis() != nil

    Process.sleep(300)
    %{data: data} = Charkeeper.get_data()
    assert map_size(data) == 1

    Charkeeper.stop()
    assert Poller.whereis() == nil
  end
end
