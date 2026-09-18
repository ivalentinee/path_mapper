defmodule PathMapperWeb.AssetServingTest do
  use PathMapperWeb.ConnCase

  alias PathMapper.AssetSource
  alias PathMapper.FileStorage

  @png <<137, 80, 78, 71, 13, 10, 26, 10>> <> "not-a-real-png-but-distinct-bytes"

  test "every named source is served at the URL storing hands back", %{conn: conn} do
    for source <- AssetSource.all() do
      :ok = FileStorage.initialize(source)
      {:ok, path} = FileStorage.store(@png <> source, "png", source)

      response = get(conn, path)

      assert response.status == 200, "#{path} returned #{response.status}"
      assert response.resp_body == @png <> source
    end
  end

  test "storing to a source outside the set is refused rather than written" do
    assert_raise FunctionClauseError, fn -> FileStorage.store(@png, "png", "uplaod") end
    assert_raise FunctionClauseError, fn -> FileStorage.initialize("global") end
  end

  test "uploads are named upload" do
    assert AssetSource.upload() == "upload"
    assert "upload" in AssetSource.all()
    refute "custom" in AssetSource.all()
  end
end
