defmodule PathMapperWeb.AssetController do
  use PathMapperWeb, :controller

  alias PathMapper.FileStorage
  alias PathMapper.UploadStorage

  def create(conn, %{"name" => name, "file" => %Plug.Upload{path: path}}) do
    with {:ok, bytes} <- File.read(path),
         :ok <- verify(bytes, name),
         :ok <- UploadStorage.initialize(),
         {:ok, stored} <- UploadStorage.store(bytes, extension(name)) do
      json(conn, %{status: "ok", path: stored})
    else
      {:error, reason} -> refuse(conn, reason)
    end
  end

  # The client names an asset by its content, so the server can check the claim
  # rather than trust it. Without this, content addressing is an assertion.
  defp verify(bytes, name) do
    computed = FileStorage.content_name(bytes)
    claimed = Path.rootname(name)

    if computed == claimed do
      :ok
    else
      {:error, "Asset bytes are named #{computed}, not #{claimed}"}
    end
  end

  defp extension(name), do: name |> Path.extname() |> String.trim_leading(".")

  defp refuse(conn, reason) when is_binary(reason),
    do: conn |> put_status(400) |> json(%{error: reason})

  defp refuse(conn, reason),
    do: conn |> put_status(500) |> json(%{error: inspect(reason)})
end
