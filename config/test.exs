use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :book_bank, BookBankWeb.Endpoint,
  http: [port: 4002],
  server: false

# dependency injection baby
config :book_bank, BookBank.DatabaseBehavior, BookBank.MockDatabase
config :book_bank, BookBank.AuthBehavior, BookBank.MockAuth
config :book_bank, BookBankWeb.Utils.JwtBehavior, BookBankWeb.Utils.MockJwt
config :book_bank, BookBank.Auth.UserWhitelistBehavior, BookBank.Auth.MockUserWhitelist
config :book_bank, BookBankWeb.Utils.ChunkBehavior, BookBankWeb.Utils.MockChunk

config :book_bank, BookBankWeb.Utils.Jwt,
  secret: "hunter2"

# config :joken, :current_time_adapter, BookBankWeb.Utils.MockJwtTime
config :joken, :current_time_adapter, Test.StubTime

# Print only warnings and errors during test
config :logger, level: :warn
