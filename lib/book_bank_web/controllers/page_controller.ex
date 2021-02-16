defmodule BookBankWeb.PageController do
  use BookBankWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def not_found(conn, %{path: path}) do
    BookBankWeb.Utils.with(conn, [], fn conn, _extra ->
      {conn, {:error, :not_found, "No handler exists at #{path}"}}
    end)
  end

  def not_found(conn, _params) do
    BookBankWeb.Utils.with(conn, [], fn conn, _extra ->
      {conn, {:error, :not_found}}
    end)
  end
end
