defmodule PathMapper.Charkeeper.PollerTest do
  @moduledoc """
  The poller runs for the life of the application and is told nothing. Each
  tick it reads the session store for characters that name a Charkeeper
  character, asks about those, and keeps the answers in a table.

  Ticks are driven here rather than waited for: `config/test.exs` holds the
  interval off so no tick reaches the real service, and `:sys.get_state/1`
  after the message is a barrier - the poll is handled before it returns.
  """
  use ExUnit.Case, async: false

  alias PathMapper.Charkeeper
  alias PathMapper.Charkeeper.Poller
  alias PathMapper.Game
  alias PathMapper.Session.Entity
  alias PathMapper.Session.Store

  setup_all do
    {:ok, pid} = Bandit.start_link(plug: PathMapper.FakeCharkeeper, port: 0, ip: :loopback)
    {:ok, {_ip, port}} = ThousandIsland.listener_info(pid)
    {:ok, port: port}
  end

  setup %{port: port} do
    Application.put_env(:path_mapper, :charkeeper_server, "http://localhost:#{port}")

    on_exit(fn ->
      Game.clear()
      Application.delete_env(:path_mapper, :charkeeper_server)
    end)

    :ok
  end

  describe "a tick" do
    test "reports the characters that name a Charkeeper character" do
      declare("pg0001-0000000001", "test-uuid-1")
      declare("pg0001-0000000002", "test-uuid-2")

      tick()

      assert %{status: :ok, data: data} = Charkeeper.get_data()
      assert %{level: 3, hp_current: 10, hp_max: 15, armor_class: 18} = data["pg0001-0000000001"]
      assert %{level: 2, hp_current: 6} = data["pg0001-0000000002"]
    end

    # Declaring a character is the whole of it. Nothing starts, restarts or
    # tells the poller anything - the call that used to do that went missing
    # when characters replaced groups, and the integration simply stopped.
    test "picks up a character declared after it has been running" do
      declare("pg0001-0000000001", "test-uuid-1")
      tick()

      declare("pg0001-0000000002", "test-uuid-2")
      tick()

      assert Charkeeper.get_data().data |> Map.keys() |> Enum.sort() ==
               ["pg0001-0000000001", "pg0001-0000000002"]
    end

    test "asks about nobody when no character names one" do
      declare("pg0001-0000000001", nil)

      tick()

      assert Charkeeper.get_data() == %{data: %{}, status: nil}
    end

    # The readings used to be merged into what was there, so a character the
    # session no longer held kept its last HP on screen for ever.
    test "forgets a character the session no longer holds" do
      declare("pg0001-0000000001", "test-uuid-1")
      declare("pg0001-0000000002", "test-uuid-2")
      tick()

      Store.delete("pg0001-0000000002")
      tick()

      assert Map.keys(Charkeeper.get_data().data) == ["pg0001-0000000001"]
    end

    test "says so when only some of them answer" do
      declare("pg0001-0000000001", "test-uuid-1")
      declare("pg0001-0000000002", "nobody-by-that-name")

      tick()

      assert %{status: :partial, data: data} = Charkeeper.get_data()
      assert Map.keys(data) == ["pg0001-0000000001"]
    end

    # A moment of network trouble should not blank the party.
    test "keeps the last reading for a character that failed this time" do
      declare("pg0001-0000000001", "test-uuid-1")
      tick()

      Application.put_env(:path_mapper, :charkeeper_server, "http://localhost:1")
      tick()

      assert %{status: :error, data: data} = Charkeeper.get_data()
      assert %{hp_current: 10} = data["pg0001-0000000001"]
    end
  end

  describe "putting the session away" do
    test "forgets the readings at once, rather than at the next tick" do
      declare("pg0001-0000000001", "test-uuid-1")
      tick()
      refute Charkeeper.get_data().data == %{}

      Game.clear()

      assert Charkeeper.get_data() == %{data: %{}, status: nil}
    end
  end

  defp tick do
    send(Poller, :poll)
    :sys.get_state(Poller)
  end

  defp declare(id, charkeeper_id) do
    params = %{"id" => id, "character_name" => "Someone", "color" => "#328546"}
    params = if charkeeper_id, do: Map.put(params, "charkeeper_id", charkeeper_id), else: params

    {:ok, entity} = Entity.build("character", params)
    {:ok, _stored} = Store.put(entity)
  end
end
