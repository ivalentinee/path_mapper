defmodule PathMapperWeb.Plugs.SchemaGateTest do
  use PathMapperWeb.ConnCase

  alias PathMapperWeb.Plugs.SchemaGate

  @test_token "test-upload-token"

  setup do
    original = Application.get_env(:path_mapper, :api_token)
    Application.put_env(:path_mapper, :api_token, @test_token)
    on_exit(fn -> Application.put_env(:path_mapper, :api_token, original) end)
    :ok
  end

  defp authorized(conn), do: put_req_header(conn, "authorization", "Bearer #{@test_token}")

  describe "through the router" do
    test "refuses a body the document does not permit", %{conn: conn} do
      conn =
        conn
        |> authorized()
        |> put_req_header("content-type", "multipart/form-data; boundary=x")
        |> post("/api/scenes/map", %{})

      assert %{"error" => _} = json_response(conn, 400)
    end

    test "refuses a content type the route does not offer", %{conn: conn} do
      conn =
        conn
        |> authorized()
        |> put_req_header("content-type", "application/json")
        |> post("/api/scenes/map", Jason.encode!(%{"file" => "x"}))

      assert %{"error" => "Unsupported content type: application/json"} = json_response(conn, 415)
    end
  end

  describe "called directly" do
    # Phoenix matches a route before any pipeline runs, so an undescribed path
    # cannot reach the gate through the router. The boot check in
    # PathMapper.Api.Document.verify_routes!/1 is what holds the route table to
    # the document; this covers the plug's own behaviour.
    test "refuses a path the document does not describe" do
      conn = SchemaGate.call(Plug.Test.conn(:post, "/api/scenes/nope"), [])

      assert conn.status == 404
      assert conn.halted
      assert Jason.decode!(conn.resp_body) == %{"error" => "No such route: POST /api/scenes/nope"}
    end

    test "passes a documented route with no body to validate" do
      conn = SchemaGate.call(Plug.Test.conn(:get, "/api/openapi.json"), [])

      refute conn.halted
    end
  end
end
