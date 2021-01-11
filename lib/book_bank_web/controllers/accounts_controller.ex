defmodule BookBankWeb.AccountsController do
  use BookBankWeb, :controller

  def login(conn, params) do
    %{username: un, password: pw} = params
    if BookBank.MongoAuth.authenticate_user?(un, pw) do

    end
  end



  def index(conn, _params) do
    render(conn, "index.html")
  end
end
