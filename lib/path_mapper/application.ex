defmodule PathMapper.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias PathMapper.Api.Document

  @impl true
  def start(_type, _args) do
    PathMapper.UploadStorage.clear()

    Document.load!()
    Document.verify_routes!(api_routes())

    children = [
      PathMapperWeb.Telemetry,
      {Phoenix.PubSub, name: PathMapper.PubSub},
      PathMapper.Session.Store,
      # Start a worker by calling: PathMapper.Worker.start_link(arg)
      # {PathMapper.Worker, arg},
      # Start to serve requests, typically the last entry
      PathMapper.Game,
      PathMapper.MapTools,
      PathMapper.Charkeeper.Supervisor,
      PathMapperWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PathMapper.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @api_prefix "/api/"

  # The document describes the API surface, which is everything under /api.
  defp api_routes do
    Enum.filter(PathMapperWeb.Router.__routes__(), &String.starts_with?(&1.path, @api_prefix))
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PathMapperWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
