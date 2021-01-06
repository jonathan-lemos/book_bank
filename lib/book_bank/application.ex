defmodule BookBank.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      BookBankWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: BookBank.PubSub},
      # Start the Endpoint (http/https)
      BookBankWeb.Endpoint,
      # Start a worker by calling: BookBank.Worker.start_link(arg)
      # {BookBank.Worker, arg}
      {Mongo, [[name: :mongo, database: System.get_env("DB_NAME") || "book_bank", pool_size: 16]]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BookBank.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    BookBankWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
