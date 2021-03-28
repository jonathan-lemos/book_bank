defmodule BookBank.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def add_if(list, condition, elem) do
    if condition do
      [elem | list]
    else
      list
    end
  end

  @spec start(any, any) :: no_return
  def start(_type, _args) do
    children =
      [
        # Start the Telemetry supervisor
        BookBankWeb.Telemetry,
        # Start the PubSub system
        {Phoenix.PubSub, name: BookBank.PubSub},
        # Start the Endpoint (http/https)
        BookBankWeb.Endpoint
        # Start a worker by calling: BookBank.Worker.start_link(arg)
        # {BookBank.Worker, arg}
      ]
      |> add_if(
        BookBank.DI.auth_service() === BookBank.MongoAuth,
        {Mongo,
         name: :mongo,
         database: "book_bank",
         url: Application.get_env(:book_bank, BookBank.MongoDatabase)[:url],
         pool_size: 16}
      )
      |> add_if(
        BookBank.DI.whitelist_service() ===
          BookBank.Auth.UserWhitelist,
        %{
          id: BookBank.Auth.UserWhitelist,
          start:
            {BookBank.Auth.UserWhitelist, :start_link,
             [[ttl_seconds: BookBankWeb.Utils.Jwt.Token.token_lifetime_seconds()]]}
        }
      )

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BookBank.Supervisor]
    res = Supervisor.start_link(children, opts)

    if BookBank.DI.auth_service() === BookBank.MongoAuth do
      :ok = BookBank.Utils.Mongo.init!()
    end

    if BookBank.DI.search_service() ===
         BookBank.ElasticSearch do
      :ok = BookBank.ElasticSearch.init()
    end

    res
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    BookBankWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
