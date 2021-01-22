defmodule BookBankWeb.Router do
  use BookBankWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", BookBankWeb do
    pipe_through :browser

    get "/", PageController, :index
  end

  scope "/api/accounts", BookBankWeb do
    pipe_through :api

    post "/login", AccountsController, :post_login
    post "/create", AccountsController, :post_create
    get "/roles", AccountsController, :get_roles
    get "/roles/:role", AccountsController, :get_user_roles
    get "/users/roles/:username", AccountsController, :get_role_accounts
    put "/users/roles/:username", AccountsController, :put_user_roles
    patch "/users/roles/:username", AccountsController, :patch_user_roles
    put "/users/password/:username", AccountsController, :put_user_password
    delete "/users/:username", AccountsController, :delete_user
  end

  scope "/api/books", BookBankWeb do
    pipe_through :api

    get "/cover/:id", BooksController, :get_book_cover
    get "/metadata/:id", BooksController, :get_book_meta
    get "/thumbnail/:id", BooksController, :get_book_thumb
    get "/download/:id", BooksController, :get_book_download
    get "/view/:id", BooksController, :get_book_view
    post "/", BooksController, :post_upload
    put "/metadata/:id", BooksController, :put_metadata
    patch "/metadata/:id", BooksController, :patch_metadata
    delete "/:id", BooksController, :delete_book
  end

  # Other scopes may use custom stacks.
  # scope "/api", BookBankWeb do
  #   pipe_through :api
  # end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: BookBankWeb.Telemetry
    end
  end
end
