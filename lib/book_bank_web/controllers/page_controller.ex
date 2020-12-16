defmodule BookBankWeb.PageController do
  use BookBankWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
