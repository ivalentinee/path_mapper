defmodule PathMapper.MixProject do
  use Mix.Project

  def project do
    [
      app: :path_mapper,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      releases: releases()
    ]
  end

  def releases do
    [
      path_mapper: [
        include_executables_for: [:unix],
        applications: [runtime_tools: :permanent],
        steps: [:assemble]
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {PathMapper.Application, []},
      extra_applications: [:logger, :runtime_tools, :xmerl, :inets, :ssl]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.7.21"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0"},
      {:ecto, "~> 3.12.5"},
      {:floki, ">= 0.30.0", only: :test},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.26"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.1.1"},
      {:bandit, "~> 1.5"},
      {:tomerl, "~> 0.5.0"},
      {:credo, "~> 1.7.12", only: [:dev, :test], runtime: false}
    ]
  end

  def cli do
    [preferred_envs: [paranoid: :test]]
  end

  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build"],
      paranoid: ["test", "format", "credo"],
      "assets.setup": ["esbuild.install --if-missing"],
      "assets.build": ["esbuild path_mapper"],
      "assets.deploy": [
        "esbuild path_mapper --minify",
        "phx.digest"
      ]
    ]
  end
end
