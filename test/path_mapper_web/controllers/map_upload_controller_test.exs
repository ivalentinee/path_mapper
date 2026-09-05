defmodule PathMapperWeb.MapUploadControllerTest do
  use PathMapperWeb.ConnCase

  alias PathMapper.Game
  alias PathMapper.Groups

  @test_token "test-upload-token"

  setup do
    original = Application.get_env(:path_mapper, :upload_token)
    Application.put_env(:path_mapper, :upload_token, @test_token)
    on_exit(fn -> Application.put_env(:path_mapper, :upload_token, original) end)
    :ok
  end

  defp auth_conn(conn) do
    put_req_header(conn, "authorization", "Bearer #{@test_token}")
  end

  defp upload_ora(conn, file_path) do
    upload = %Plug.Upload{
      path: file_path,
      filename: "map.ora",
      content_type: "application/octet-stream"
    }

    post(conn, "/api/scenes/map", %{"file" => upload})
  end

  describe "authentication" do
    test "returns 401 without token", %{conn: conn} do
      conn = post(conn, "/api/scenes/map")
      assert json_response(conn, 401) == %{"error" => "Unauthorized"}
    end

    test "returns 401 with wrong token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer wrong-token")
        |> post("/api/scenes/map")

      assert json_response(conn, 401) == %{"error" => "Unauthorized"}
    end
  end

  describe "upload" do
    test "returns 400 when no file uploaded", %{conn: conn} do
      conn = conn |> auth_conn() |> post("/api/scenes/map", %{})
      assert json_response(conn, 400) == %{"error" => "No file uploaded"}
    end

    test "returns 400 when no game loaded", %{conn: conn} do
      Game.clear()
      ora_path = "test/data/adventures/unpacked/map.ora"
      conn = conn |> auth_conn() |> upload_ora(ora_path)
      assert %{"error" => _} = json_response(conn, 400)
    end

    test "returns 400 when no active scene", %{conn: conn} do
      load_adventure("adventure-1.zip")
      {:ok, _group} = Groups.load_group("group-1.zip")

      # Create a custom scene then unset active scene
      :ok = Game.run_action([:scene, :create], %{"name" => "Upload Test"})
      :ok = Game.run_action([:scene, :unset], nil)

      ora_path = "test/data/adventures/unpacked/map.ora"
      conn = conn |> auth_conn() |> upload_ora(ora_path)
      assert %{"error" => "No active scene"} = json_response(conn, 400)
    end

    test "successfully uploads ORA file to active custom scene", %{conn: conn} do
      load_adventure("adventure-1.zip")
      {:ok, _group} = Groups.load_group("group-1.zip")
      :ok = Game.run_action([:scene, :create], %{"name" => "Upload Test"})

      ora_path = "test/data/adventures/unpacked/map.ora"
      conn = conn |> auth_conn() |> upload_ora(ora_path)
      assert json_response(conn, 200) == %{"status" => "ok"}

      # Verify game state was updated
      state = Game.get_state()
      assert state.scene != nil
      assert state.scene.data != nil
      assert state.scene.data.map != nil
      assert length(state.scene.map.layers) > 0
    end

    test "preserves tokens on re-upload", %{conn: conn} do
      load_adventure("adventure-1.zip")
      {:ok, _group} = Groups.load_group("group-1.zip")
      :ok = Game.run_action([:scene, :create], %{"name" => "Upload Test"})

      # Place a token first
      :ok =
        Game.run_action([:tokens, :add_adhoc], %{
          label: "Test Token",
          owner: "GM",
          size: 1
        })

      ora_path = "test/data/adventures/unpacked/map.ora"

      # First upload
      conn1 = conn |> auth_conn() |> upload_ora(ora_path)
      assert json_response(conn1, 200) == %{"status" => "ok"}

      state1 = Game.get_state()
      assert length(state1.scene.tokens) == 1

      # Re-upload
      conn2 = build_conn() |> auth_conn() |> upload_ora(ora_path)
      assert json_response(conn2, 200) == %{"status" => "ok"}

      state2 = Game.get_state()
      assert length(state2.scene.tokens) == 1
    end
  end
end
