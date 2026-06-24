defmodule PathMapper.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PathMapperWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:path_mapper, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: PathMapper.PubSub},
      # Start a worker by calling: PathMapper.Worker.start_link(arg)
      # {PathMapper.Worker, arg},
      # Start to serve requests, typically the last entry
      PathMapper.Adventures,
      PathMapper.Groups,
      PathMapper.GlobalTokens,
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

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PathMapperWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
