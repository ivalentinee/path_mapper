defmodule PathMapperWeb.Plugs.TokenAuth do
  @moduledoc false

  import Plug.Conn

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    with {:ok, configured_token} <- get_configured_token(),
         {:ok, request_token} <- get_bearer_token(conn),
         :ok <- verify_token(request_token, configured_token) do
      conn
    else
      :error -> unauthorized(conn)
    end
  end

  defp get_configured_token do
    case Application.get_env(:path_mapper, :upload_token) do
      nil -> :error
      "" -> :error
      token when is_binary(token) -> {:ok, token}
    end
  end

  defp get_bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, token}
      _ -> :error
    end
  end

  defp verify_token(request_token, configured_token) do
    if Plug.Crypto.secure_compare(request_token, configured_token) do
      :ok
    else
      :error
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, Jason.encode!(%{error: "Unauthorized"}))
    |> halt()
  end
end
