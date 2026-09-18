defmodule PathMapperWeb.AssetControllerTest do
  use PathMapperWeb.ConnCase

  alias PathMapper.FileStorage
  alias PathMapper.UploadStorage

  @test_token "test-upload-token"
  @bytes "not really a png, but bytes all the same"

  setup do
    original = Application.get_env(:path_mapper, :api_token)
    Application.put_env(:path_mapper, :api_token, @test_token)
    on_exit(fn -> Application.put_env(:path_mapper, :api_token, original) end)
    :ok
  end

  defp post_asset(conn, name, bytes) do
    path = Path.join(System.tmp_dir!(), "asset-#{System.unique_integer([:positive])}")
    File.write!(path, bytes)
    on_exit(fn -> File.rm(path) end)

    upload = %Plug.Upload{path: path, filename: name, content_type: "application/octet-stream"}

    conn
    |> put_req_header("authorization", "Bearer #{@test_token}")
    |> put_req_header("content-type", "multipart/form-data; boundary=plug_conn_test")
    |> post("/api/assets", %{"name" => name, "file" => upload})
  end

  defp content_name(bytes), do: "#{FileStorage.content_name(bytes)}.png"

  test "stores an asset sent under the name its bytes hash to", %{conn: conn} do
    name = content_name(@bytes)
    conn = post_asset(conn, name, @bytes)

    assert %{"status" => "ok", "path" => path} = json_response(conn, 200)
    assert path == "/upload/#{name}"
    assert {:ok, @bytes} = FileStorage.read_stored(path)
  end

  test "refuses bytes that do not hash to the name they arrived under", %{conn: conn} do
    conn = post_asset(conn, content_name("different bytes entirely"), @bytes)

    assert %{"error" => error} = json_response(conn, 400)
    assert error =~ "are named"
  end

  test "storing the same bytes twice changes nothing", %{conn: conn} do
    name = content_name(@bytes)

    first = conn |> post_asset(name, @bytes) |> json_response(200)
    second = build_conn() |> post_asset(name, @bytes) |> json_response(200)

    assert first == second
  end

  test "refuses without a token", %{conn: conn} do
    name = content_name(@bytes)

    path = Path.join(System.tmp_dir!(), "asset-unauth")
    File.write!(path, @bytes)
    on_exit(fn -> File.rm(path) end)
    upload = %Plug.Upload{path: path, filename: name, content_type: "application/octet-stream"}

    conn =
      conn
      |> put_req_header("content-type", "multipart/form-data; boundary=plug_conn_test")
      |> post("/api/assets", %{"name" => name, "file" => upload})

    assert json_response(conn, 401)
  end

  describe "clearing" do
    test "clear/0 empties the store" do
      :ok = UploadStorage.initialize()
      {:ok, path} = UploadStorage.store(@bytes, "png")
      assert {:ok, _} = FileStorage.read_stored(path)

      :ok = UploadStorage.clear()

      assert {:error, :enoent} = FileStorage.read_stored(path)
    end
  end
end
