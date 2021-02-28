# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

# Configures the endpoint
config :book_bank, BookBankWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "BViZt4cpHMImCrfuSpHn9okXXGqb3rYxRbRPfhXC5D6SfHNJOEUVoNfv3hd5X/SZ",
  render_errors: [view: BookBankWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: BookBank.PubSub,
  live_view: [signing_salt: "HLswLhK+"]

config :book_bank, :env, Mix.env()

config :book_bank, BookBankWeb.Utils.Jwt.Token, lifetime_seconds: 2 * 60 * 60

config :book_bank, BookBank.MongoDatabase,
  url: System.get_env("MONGO_CONNECTION_URL") || "mongodb://localhost:27017/book_bank",
  pool_size: (System.get_env("MONGO_POOL_SIZE") || "16") |> String.to_integer()

config :book_bank, BookBank.ElasticSearch,
  url: System.get_env("ELASTIC_CONNECTION_URL") || "http://localhost:9200",
  index: System.get_env("ELASTIC_BOOK_INDEX") || "books"

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :joken, :current_time_adapter, BookBankWeb.Utils.JwtTime

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
