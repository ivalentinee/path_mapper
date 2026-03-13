import Config

config :path_mapper,
       :adventure_base_path,
       Application.get_env(:path_mapper, :adventure_base_path) ||
         System.get_env("ADVENTURE_BASE_PATH") || "adventures"

config :path_mapper,
       :group_base_path,
       Application.get_env(:path_mapper, :group_base_path) ||
         System.get_env("GROUP_BASE_PATH") || "groups"

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
