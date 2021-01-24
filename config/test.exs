use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :book_bank, BookBankWeb.Endpoint,
  http: [port: 4002],
  server: false

# dependency injection baby
config :book_bank, BookBank.Database, BookBank.MockDatabase
config :book_bank, BookBank.Auth, BookBank.MockAuth
config :book_bank, BookBankWeb.Utils.AuthBehavior, BookBankWeb.Utils.MockAuth

# Print only warnings and errors during test
config :logger, level: :warn
