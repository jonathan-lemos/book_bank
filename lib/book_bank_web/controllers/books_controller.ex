defmodule BookBankWeb.BooksController do
  use BookBankWeb, :controller

  @spec post_upload(Plug.Conn.t(), %{String.t() => term()}) :: Plug.Conn.t()
  def post_upload(conn, %{"title" => title, "book" => %Plug.Upload{content_type: "application/pdf", path: path}}) when is_binary(title) do
    BookBankWeb.Utils.with(conn, [authentication: ["librarian", "admin"]], fn conn, _extra ->
      obj = case BookBank.MongoDatabase.create_book(title, File.stream!(path, [], 4096), %{}) do
        {:ok, %BookBank.Book{id: id}} ->
          {:ok, :created, %{"id" => id}}
        {:error, str} ->
          {:error, :internal_server_error, str}
      end
      {conn, obj}
    end)
  end
end
