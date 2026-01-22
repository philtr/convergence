import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :convergence, ConvergenceWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "YVVGI2p+arue2Dsm9iGbBjLMfeSaJ1LVsd3iSOaoLz03CQqTP0T4kRyu9H2KsJjj",
  server: false

config :convergence, heartbeat_ms: 10

# In test we don't send emails
config :convergence, Convergence.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
