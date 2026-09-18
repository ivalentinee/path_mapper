import Config

config :path_mapper,
       :subpixel_factor,
       Application.get_env(:path_mapper, :subpixel_factor) || 10

config :path_mapper,
       :charkeeper_server,
       System.get_env("CHARKEEPER_SERVER") || "charkeeper.ru"

config :path_mapper,
       :charkeeper_poll_interval,
       String.to_integer(System.get_env("CHARKEEPER_POLL_INTERVAL") || "10000")

config :path_mapper,
       :api_token,
       System.get_env("API_TOKEN")

if cacertfile = System.get_env("CACERTFILE") do
  config :path_mapper, :cacertfile, cacertfile
end

if config_env() == :prod do
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :path_mapper, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :path_mapper, PathMapperWeb.Endpoint,
    server: true,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {127, 0, 0, 1},
      port: port
    ],
    secret_key_base: secret_key_base
end
