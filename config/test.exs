use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :book_bank, BookBankWeb.Endpoint,
  http: [port: 4002],
  server: false

config :book_bank, BookBank.MongoDatabase,
  url: System.get_env("MONGO_CONNECTION_URL") || "mongodb://localhost:27017/test"

config :book_bank, BookBank.ElasticSearch,
  url: System.get_env("ELASTIC_CONNECTION_URL") || "http://localhost:9200",
  index: System.get_env("ELASTIC_BOOK_INDEX") || "test"

config :book_bank, :testing, true

config :book_bank, BookBankWeb.Utils.Jwt, secret: "hunter2"

# config :joken, :current_time_adapter, BookBankWeb.Utils.MockJwtTime
config :joken, :current_time_adapter, Test.StubTime

# Print only warnings and errors during test
config :logger, level: :warn
