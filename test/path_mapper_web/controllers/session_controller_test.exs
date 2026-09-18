defmodule PathMapperWeb.SessionControllerTest do
  use PathMapperWeb.ConnCase

  alias PathMapper.Adventures
  alias PathMapper.FileStorage
  alias PathMapper.Game
  alias PathMapper.Groups
  alias PathMapper.UploadStorage

  @test_token "test-upload-token"

  setup do
    original = Application.get_env(:path_mapper, :api_token)
    Application.put_env(:path_mapper, :api_token, @test_token)
    on_exit(fn -> Application.put_env(:path_mapper, :api_token, original) end)
    :ok
  end

  defp reset(conn) do
    conn
    |> put_req_header("authorization", "Bearer #{@test_token}")
    |> post("/api/reset")
  end

  test "unloads the adventure, the group, the session and the store", %{conn: conn} do
    load_adventure("tt0001-0000000001-adventure-1.zip")
    {:ok, _group} = load_group("tg0001-0000000001-group-1.zip")
    :ok = UploadStorage.initialize()
    {:ok, stored} = UploadStorage.store("some bytes", "png")

    assert json_response(reset(conn), 200) == %{"status" => "ok"}

    assert Game.get_state() == nil
    assert {:error, _} = Adventures.get_loaded()
    assert {:error, _} = Groups.get_loaded()
    assert {:error, :enoent} = FileStorage.read_stored(stored)
  end

  test "refuses without a token", %{conn: conn} do
    assert json_response(post(conn, "/api/reset"), 401)
  end
end
