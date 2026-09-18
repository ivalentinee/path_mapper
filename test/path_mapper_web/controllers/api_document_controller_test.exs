defmodule PathMapperWeb.ApiDocumentControllerTest do
  use PathMapperWeb.ConnCase

  alias PathMapper.Api.Document

  test "serves the contract without a token", %{conn: conn} do
    conn = get(conn, "/api/openapi.json")
    assert json_response(conn, 200)["openapi"] == "3.0.3"
  end

  test "serves the document the gate enforces", %{conn: conn} do
    conn = get(conn, "/api/openapi.json")
    assert json_response(conn, 200) == Jason.decode!(Jason.encode!(Document.contract()))
  end

  test "is unaffected by a wrong token", %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "Bearer nonsense")
      |> get("/api/openapi.json")

    assert json_response(conn, 200)
  end
end
