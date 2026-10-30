defmodule PathMapperWeb.SessionControllerTest do
  use PathMapperWeb.ConnCase

  alias PathMapper.FileStorage
  alias PathMapper.Game
  alias PathMapper.Session.Store
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

  test "unloads the session and the store", %{conn: conn} do
    load_session()
    load_party()
    :ok = UploadStorage.initialize()
    {:ok, stored} = UploadStorage.store("some bytes", "png")

    assert json_response(reset(conn), 200) == %{"status" => "ok"}

    assert Game.get_state() == nil
    assert Store.all() == []
    assert {:error, :enoent} = FileStorage.read_stored(stored)
  end

  test "refuses without a token", %{conn: conn} do
    assert json_response(post(conn, "/api/reset"), 401)
  end

  # A snapshot is `GET /api/entities` written to a file and posted back, so
  # whatever the store hands over has to be something the gate will take. It
  # was not: an optional field nobody had set came out as null, and the
  # contract describes no null anywhere, so restoring a snapshot of a session
  # with a character in it was refused at the first entity.
  describe "what the store hands over" do
    test "is accepted back, entity for entity", %{conn: conn} do
      load_session()
      load_party()

      %{"entities" => commands} = json_response(authorized(conn) |> get("/api/entities"), 200)

      refute commands == []

      for command <- commands do
        assert %{"status" => "ok"} =
                 json_response(post_entity(conn, command), 200),
               "the store handed over a #{command["kind"]} the gate refuses: #{inspect(command)}"
      end
    end

    test "carries no nulls, because the contract describes none", %{conn: conn} do
      load_session()
      load_party()

      %{"entities" => commands} = json_response(authorized(conn) |> get("/api/entities"), 200)
      nulls = for c <- commands, {field, nil} <- c, do: {c["kind"], field}

      assert nulls == []
    end
  end

  defp authorized(conn), do: put_req_header(conn, "authorization", "Bearer #{@test_token}")

  defp post_entity(conn, command) do
    conn
    |> authorized()
    |> put_req_header("content-type", "application/json")
    |> post("/api/entities", Jason.encode!(command))
  end
end
