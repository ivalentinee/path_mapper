defmodule PathMapperWeb.MapUploadControllerTest do
  use PathMapperWeb.ConnCase

  alias PathMapper.Game
  alias PathMapper.Groups
  alias PathMapper.Session.Commands

  @test_token "test-upload-token"

  setup do
    original = Application.get_env(:path_mapper, :api_token)
    Application.put_env(:path_mapper, :api_token, @test_token)
    on_exit(fn -> Application.put_env(:path_mapper, :api_token, original) end)
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

    conn |> as_form_data() |> post("/api/scenes/map", %{"file" => upload})
  end

  # Plug.Test labels an encoded body multipart/mixed; a real client sends
  # multipart/form-data, which is what the contract describes. The boundary is
  # the one Plug.Test encoded with, so the body still parses.
  defp as_form_data(conn) do
    put_req_header(conn, "content-type", "multipart/form-data; boundary=plug_conn_test")
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
      conn = conn |> auth_conn() |> as_form_data() |> post("/api/scenes/map", %{})
      assert %{"error" => _} = json_response(conn, 400)
    end

    test "returns 400 when no game loaded", %{conn: conn} do
      Game.clear()
      ora_path = "test/data/adventures/unpacked/map.ora"
      conn = conn |> auth_conn() |> upload_ora(ora_path)
      assert %{"error" => _} = json_response(conn, 400)
    end

    test "returns 400 when no active scene", %{conn: conn} do
      load_adventure("tt0001-0000000001-adventure-1.zip")
      {:ok, _group} = load_group("tg0001-0000000001-group-1.zip")

      # Create a custom scene then unset active scene
      {:ok, scene} = Commands.create_scene("Upload Test")
      :ok = Game.run_action([:scene, :select], scene.id)
      :ok = Game.run_action([:scene, :unset], nil)

      ora_path = "test/data/adventures/unpacked/map.ora"
      conn = conn |> auth_conn() |> upload_ora(ora_path)
      assert %{"error" => "No active scene"} = json_response(conn, 400)
    end

    test "successfully uploads ORA file to active custom scene", %{conn: conn} do
      load_adventure("tt0001-0000000001-adventure-1.zip")
      {:ok, _group} = load_group("tg0001-0000000001-group-1.zip")
      {:ok, scene} = Commands.create_scene("Upload Test")
      :ok = Game.run_action([:scene, :select], scene.id)

      ora_path = "test/data/adventures/unpacked/map.ora"
      conn = conn |> auth_conn() |> upload_ora(ora_path)
      assert json_response(conn, 200) == %{"status" => "ok"}

      # Verify game state was updated
      state = Game.get_state()
      assert state.scene != nil
      assert state.scene.data != nil
      assert state.scene.data.map != nil
      assert state.scene.map.layers != []
    end

    test "preserves tokens on re-upload", %{conn: conn} do
      load_adventure("tt0001-0000000001-adventure-1.zip")
      {:ok, _group} = load_group("tg0001-0000000001-group-1.zip")
      {:ok, scene} = Commands.create_scene("Upload Test")
      :ok = Game.run_action([:scene, :select], scene.id)

      # A token made at the table is a token entity with no image, declared by
      # command and then placed like any other.
      {:ok, _token} =
        Commands.put(%PathMapper.Session.Entity{
          id: "tk0009-0000000001",
          kind: "token",
          data: %PathMapper.Adventures.Adventure.Scene.Token{
            id: "tk0009-0000000001",
            name: "Test Token",
            owner: "GM",
            size: 1
          }
        })

      {:ok, _scene} = Commands.bind_token(scene.id, "tk0009-0000000001")
      :ok = Game.run_action([:tokens, :add], "tk0009-0000000001")

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
