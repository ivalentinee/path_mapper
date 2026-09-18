defmodule PathMapperWeb.StateController do
  use PathMapperWeb, :controller

  alias PathMapper.Game

  def show(conn, _params) do
    case Game.dump_state() do
      {:ok, state} -> json(conn, state)
      {:error, reason} -> conn |> put_status(400) |> json(%{error: reason})
    end
  end

  def update(conn, params) do
    case Game.restore_state(Map.drop(params, ~w(action controller))) do
      :ok -> json(conn, %{status: "ok"})
      {:error, reason} when is_binary(reason) -> conn |> put_status(400) |> json(%{error: reason})
      {:error, other} -> conn |> put_status(400) |> json(%{error: inspect(other)})
    end
  end
end
