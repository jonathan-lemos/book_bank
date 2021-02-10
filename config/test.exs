use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :book_bank, BookBankWeb.Endpoint,
  http: [port: 4002],
  server: false

config :book_bank, BookBank.MongoDatabase,
  url: System.get_env("MONGO_TEST_CONNECTION_URL") || "mongodb://localhost:27017/test"

# dependency injection baby
config :book_bank, :services, [
  {BookBank.DatabaseBehavior, BookBank.MockDatabase},
  {BookBank.AuthBehavior, BookBank.MockAuth},
  {BookBankWeb.Utils.JwtBehavior, BookBankWeb.Utils.MockJwt},
  {BookBank.Auth.UserWhitelistBehavior, BookBank.Auth.MockUserWhitelist},
  {BookBankWeb.Utils.ChunkBehavior, BookBankWeb.Utils.MockChunk},
  {BookBank.SearchBehavior, BookBank.MockSearch},
  {BookBank.ThumbnailBehavior, BookBank.MockThumbnail}
]

config :book_bank, :testing, true

config :book_bank, BookBankWeb.Utils.Jwt, secret: "hunter2"

# config :joken, :current_time_adapter, BookBankWeb.Utils.MockJwtTime
config :joken, :current_time_adapter, Test.StubTime

# Print only warnings and errors during test
config :logger, level: :warn
