defmodule PathMapperWeb.SnapshotController do
  use PathMapperWeb, :controller

  alias PathMapper.Adventures
  alias PathMapper.Game
  alias PathMapper.Game.Snapshot
  alias PathMapper.Groups

  def download(conn, _params) do
    with {:ok, manifest} <- Game.dump_state(),
         {:ok, archive} <- Snapshot.pack(manifest) do
      send_download(conn, {:binary, archive}, filename: filename())
    else
      {:error, reason} -> text_error(conn, 400, reason)
    end
  end

  def upload(conn, %{"file" => %Plug.Upload{path: path}}) do
    with {:ok, binary} <- File.read(path),
         {:ok, manifest} <- Snapshot.unpack(binary),
         :ok <- Game.restore_state(manifest) do
      json(conn, %{status: "ok"})
    else
      {:error, reason} -> text_error(conn, 400, reason)
    end
  end

  def upload(conn, _params), do: text_error(conn, 400, "No file uploaded")

  defp filename do
    ids =
      [loaded_id(Adventures), loaded_id(Groups)]
      |> Enum.reject(&is_nil/1)
      |> Enum.join("-")

    stamp = Calendar.strftime(DateTime.utc_now(), "%Y-%m-%d-%H-%M")
    "snapshot-#{ids}-#{stamp}.zip"
  end

  defp loaded_id(source) do
    case source.get_loaded() do
      {:ok, %{id: id}} -> id
      _ -> nil
    end
  end

  defp text_error(conn, status, reason) when is_binary(reason) do
    conn |> put_status(status) |> json(%{error: reason})
  end

  defp text_error(conn, status, reason) do
    conn |> put_status(status) |> json(%{error: inspect(reason)})
  end
end
