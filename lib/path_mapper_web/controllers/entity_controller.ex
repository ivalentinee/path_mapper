defmodule PathMapperWeb.EntityController do
  use PathMapperWeb, :controller

  alias PathMapper.Game
  alias PathMapper.Session.Encode
  alias PathMapper.Session.Entity
  alias PathMapper.Session.Store

  def create(conn, %{"kind" => kind} = params) do
    with {:ok, entity} <- Entity.build(kind, Map.drop(params, ~w(kind action controller))),
         {:ok, _stored} <- Store.put(entity) do
      Game.reconcile()
      json(conn, %{status: "ok"})
    else
      error -> refuse(conn, error)
    end
  end

  def create(conn, _params), do: refuse(conn, {:error, "An entity needs a kind"})

  def delete(conn, %{"id" => id}) do
    :ok = Store.delete(id)
    Game.reconcile()
    json(conn, %{status: "ok"})
  end

  # In dependency order, so replaying the list as it stands works: what a scene
  # names exists before the scene does.
  @order %{"token" => 0, "map" => 1, "scene" => 2, "adventure" => 3, "group" => 4}

  def index(conn, _params) do
    entities =
      Store.all()
      |> Enum.sort_by(&{Map.get(@order, &1.kind, 9), &1.id})
      |> Enum.map(&Encode.command/1)

    json(conn, %{entities: entities})
  end

  defp refuse(conn, {:error, reason}) when is_binary(reason),
    do: conn |> put_status(400) |> json(%{error: reason})

  defp refuse(conn, {:error, %Ecto.Changeset{} = changeset}),
    do:
      conn
      |> put_status(400)
      |> json(%{error: Enum.join(PathMapper.Errors.format_load_error({:error, changeset}), "; ")})

  defp refuse(conn, other),
    do: conn |> put_status(400) |> json(%{error: inspect(other)})
end
