defmodule PathMapperWeb.SessionController do
  use PathMapperWeb, :controller

  alias PathMapper.Game

  def reset(conn, _params) do
    :ok = Game.clear()
    json(conn, %{status: "ok"})
  end
end
