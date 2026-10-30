import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :path_mapper, PathMapperWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "kzMZLsD0yMw0C+e0HTrjZPK58DVTwkn1DqVqTWfsZXI6pTKjIa1Qxxhmd0eZAgbK",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# The Charkeeper poller runs for the life of the application. Held off here so
# that it never ticks of its own accord during a test run - one that did would
# reach the real service, since the fake is started per test on its own port.
# Tests drive it a tick at a time instead.
config :path_mapper, :charkeeper_poll_interval, 3_600_000

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
