# In this file, we load production configuration and secrets
# from environment variables. You can also hardcode secrets,
# although such is generally not recommended and you have to
# remember to add this file to your .gitignore.
use Mix.Config

secret_key_base =
  System.get_env("SECRET_KEY_BASE") ||
    raise """
    environment variable SECRET_KEY_BASE is missing.
    You can generate one by calling: mix phx.gen.secret
    """

config :book_bank, BookBankWeb.Endpoint,
  http: [
    port: String.to_integer(System.get_env("PORT") || "4000"),
    transport_options: [socket_opts: [:inet6]]
  ],
  secret_key_base: secret_key_base

config :book_bank, BookBankWeb.Utils.Jwt,
  secret:
    System.get_env("AUTH_SECRET") ||
      raise("""
      environment variable AUTH_SECRET is missing.
      """)

config :book_bank, BookBank.MongoAuth,
  default_credentials:
    {System.get_env("DEFAULT_USERNAME") || "admin",
     System.get_env("DEFAULT_PASSWORD") || "hunter2"}

# ## Using releases (Elixir v1.9+)
#
# If you are doing OTP releases, you need to instruct Phoenix
# to start each relevant endpoint:
#
#     config :book_bank, BookBankWeb.Endpoint, server: true
#
# Then you can assemble a release by calling `mix release`.
# See `mix help release` for more information.
