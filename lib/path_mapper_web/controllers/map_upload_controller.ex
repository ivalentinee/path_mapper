defmodule PathMapperWeb.MapUploadController do
  use PathMapperWeb, :controller

  alias PathMapper.CustomFileStorage
  alias PathMapper.CustomMapBuilder
  alias PathMapper.Game
  alias PathMapper.ORAReader

  def upload(conn, %{"file" => %Plug.Upload{path: path}}) do
    with {:ok, binary} <- File.read(path),
         {:ok, ora_data} <- parse_ora(binary),
         :ok <- CustomFileStorage.initialize(),
         {:ok, adventure_map} <- CustomMapBuilder.build(ora_data),
         :ok <- run_set_map(adventure_map) do
      json(conn, %{status: "ok"})
    else
      {:error, reason} ->
        handle_error(conn, reason)
    end
  end

  def upload(conn, _params) do
    conn
    |> put_status(400)
    |> json(%{error: "No file uploaded"})
  end

  defp parse_ora(binary) do
    case ORAReader.read_from_file(binary) do
      {:ok, _} = result -> result
      {:error, reason} -> {:error, reason}
      error -> {:error, "ORA parse error: #{inspect(error)}"}
    end
  end

  defp run_set_map(adventure_map) do
    case Game.run_action([:scene, :set_map], adventure_map) do
      :ok -> :ok
      {:error, _} = error -> error
    end
  end

  defp handle_error(conn, "No adventure loaded") do
    conn |> put_status(400) |> json(%{error: "No game loaded"})
  end

  defp handle_error(conn, "No active scene") do
    conn |> put_status(400) |> json(%{error: "No active scene"})
  end

  defp handle_error(conn, reason) when is_binary(reason) do
    conn |> put_status(400) |> json(%{error: reason})
  end

  defp handle_error(conn, reason) do
    conn |> put_status(500) |> json(%{error: inspect(reason)})
  end
end
