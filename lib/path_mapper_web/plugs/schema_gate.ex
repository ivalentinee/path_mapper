defmodule PathMapperWeb.Plugs.SchemaGate do
  @moduledoc """
  Holds every request in the guarded pipeline to what the API document describes.

  A path the document does not name is refused before any controller sees it, so
  the document is the upper bound on the route table and not only on request
  bodies.
  """

  import Plug.Conn

  alias PathMapper.Api.Document

  def init(opts), do: opts

  def call(conn, _opts) do
    case Document.operation(conn.method, conn.request_path) do
      nil -> refuse(conn, 404, "No such route: #{conn.method} #{conn.request_path}")
      operation -> validate(conn, operation)
    end
  end

  defp validate(conn, %{schemas: schemas}) when map_size(schemas) == 0, do: conn

  defp validate(conn, %{schemas: schemas}) do
    type = content_type(conn)

    case Map.get(schemas, type) do
      nil -> refuse(conn, 415, "Unsupported content type: #{type}")
      schema -> against(conn, schema)
    end
  end

  defp against(conn, schema) do
    case ExJsonSchema.Validator.validate(schema, normalize(conn.params)) do
      :ok -> conn
      {:error, errors} -> refuse(conn, 400, explain(errors))
    end
  end

  # A file part is a string to the document (format: binary), so the upload's name
  # stands in for it and its bytes never reach the validator.
  defp normalize(%Plug.Upload{filename: filename}), do: filename

  defp normalize(value) when is_map(value) and not is_struct(value) do
    Map.new(value, fn {key, inner} -> {key, normalize(inner)} end)
  end

  defp normalize(value) when is_list(value), do: Enum.map(value, &normalize/1)
  defp normalize(value), do: value

  defp explain([{message, pointer} | _rest]), do: "#{pointer}: #{message}"
  defp explain(errors), do: inspect(errors)

  defp content_type(conn) do
    conn
    |> get_req_header("content-type")
    |> List.first("")
    |> String.split(";")
    |> List.first()
    |> String.trim()
  end

  defp refuse(conn, status, reason) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(%{error: reason}))
    |> halt()
  end
end
