defmodule PathMapperWeb.ApiDocumentController do
  use PathMapperWeb, :controller

  alias PathMapper.Api.Document

  def show(conn, _params), do: json(conn, Document.contract())
end
