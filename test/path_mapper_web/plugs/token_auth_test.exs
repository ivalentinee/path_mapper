defmodule PathMapperWeb.Plugs.TokenAuthTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import Plug.Conn

  alias PathMapperWeb.Plugs.TokenAuth

  @test_token "test-secret-token"

  setup do
    original = Application.get_env(:path_mapper, :upload_token)
    on_exit(fn -> Application.put_env(:path_mapper, :upload_token, original) end)
    :ok
  end

  test "passes through with valid token" do
    Application.put_env(:path_mapper, :upload_token, @test_token)

    conn =
      :post
      |> conn("/api/scenes/map")
      |> put_req_header("authorization", "Bearer #{@test_token}")
      |> TokenAuth.call([])

    refute conn.halted
  end

  test "halts with 401 when token is wrong" do
    Application.put_env(:path_mapper, :upload_token, @test_token)

    conn =
      :post
      |> conn("/api/scenes/map")
      |> put_req_header("authorization", "Bearer wrong-token")
      |> TokenAuth.call([])

    assert conn.halted
    assert conn.status == 401
    assert Jason.decode!(conn.resp_body) == %{"error" => "Unauthorized"}
  end

  test "halts with 401 when no authorization header" do
    Application.put_env(:path_mapper, :upload_token, @test_token)

    conn =
      :post
      |> conn("/api/scenes/map")
      |> TokenAuth.call([])

    assert conn.halted
    assert conn.status == 401
  end

  test "halts with 401 when no token configured (nil)" do
    Application.put_env(:path_mapper, :upload_token, nil)

    conn =
      :post
      |> conn("/api/scenes/map")
      |> put_req_header("authorization", "Bearer some-token")
      |> TokenAuth.call([])

    assert conn.halted
    assert conn.status == 401
  end

  test "halts with 401 when token configured as empty string" do
    Application.put_env(:path_mapper, :upload_token, "")

    conn =
      :post
      |> conn("/api/scenes/map")
      |> put_req_header("authorization", "Bearer some-token")
      |> TokenAuth.call([])

    assert conn.halted
    assert conn.status == 401
  end

  test "halts with 401 for non-Bearer authorization" do
    Application.put_env(:path_mapper, :upload_token, @test_token)

    conn =
      :post
      |> conn("/api/scenes/map")
      |> put_req_header("authorization", "Basic dXNlcjpwYXNz")
      |> TokenAuth.call([])

    assert conn.halted
    assert conn.status == 401
  end
end
