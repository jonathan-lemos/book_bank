defmodule BookBankWeb.BooksController do
  use BookBankWeb, :controller

  @spec post_upload(Plug.Conn.t(), %{String.t() => term()}) :: Plug.Conn.t()
  def post_upload(conn, %{
        "title" => title,
        "book" => %Plug.Upload{content_type: "application/pdf", path: path}
      })
      when is_binary(title) do
    BookBankWeb.Utils.with(conn, [authentication: ["librarian", "admin"]], fn conn, _extra ->
      obj =
        case BookBank.MongoDatabase.create_book(title, File.stream!(path, [], 4096), %{}) do
          {:ok, %BookBank.Book{id: id}} ->
            {:ok, :created, %{"id" => id}}

          {:error, str} ->
            {:error, :internal_server_error, str}
        end

      {conn, obj}
    end)
  end

  def post_upload(conn, _params) do
    BookBankWeb.Utils.with(conn, [authentication: ["librarian", "admin"]], fn conn, _extra ->
      {conn,
       {:error, :bad_request,
        "This endpoint requires a multipart/form-data request body with a string 'title' and a file upload 'book'."}}
    end)
  end

  def put_metadata_params_update_list([], acc) do
    if length(acc) == 0 do
      {:error, "'title' and/or 'metadata' must be set."}
    else
      {:ok, acc}
    end
  end

  def put_metadata_params_update_list([head | tail], acc) do
    case head do
      {"title", title} when is_binary(title) -> put_metadata_params_update_list(tail, [{:set_title, title} | acc])
      {"title", _} -> {:error, "'title' must be a string"}
      {"metadata", metadata} when is_map(metadata) ->
        if Enum.all?(metadata, fn
             {k, v} when is_binary(k) and is_binary(v) -> true
             _ -> false
           end) do
            put_metadata_params_update_list(tail, [{:replace_metadata, metadata} | acc])
           else
            {:error, "'metadata' must be { [string]: string }"}
           end
      {"metadata", _} -> {:error, "'metadata' must be { [string]: string }"}
      _ -> put_metadata_params_update_list(tail, acc)
    end
  end

  def put_metadata_params_update_list(params) when is_map(params) do
    put_metadata_params_update_list(Map.to_list(params), [])
  end

  def put_metadata(conn, %{"id" => id} = params) when is_binary(id) do
    BookBankWeb.Utils.with(conn, [authentication: ["librarian", "admin"]], fn conn, _extra ->
      obj = with {:ok, update_list} <- put_metadata_params_update_list(params) do
        case BookBank.MongoDatabase.update_book(id, update_list) do
          :ok -> {:ok, :ok}
          {:error, :does_not_exist} -> {:error, :not_found, "No such book with id #{id}"}
          {:error, str} -> {:error, :internal_server_error, str}
        end
      else
        {:error, e} -> {:error, :bad_request, e}
      end

      {conn, obj}
    end)
  end

  def put_metadata(conn, _params)
    BookBankWeb.Utils.with(conn, [authentication: ["librarian", "admin"]], fn conn, _extra ->
      {conn, {:error, :not_found}
    end)
  end

  def put_metadata(conn, _params) do
    BookBankWeb.Utils.with(conn, [authentication: ["librarian", "admin"]], fn conn, _extra ->
      {conn,
       {:error, :bad_request,
        "This endpoint requires {id: string, metadata: { [string]: string } in the request body."}}
    end)
  end

  def patch_metadata(conn, %{id: id, title: title, add: add, remove: remove})
      when is_binary(id) and is_binary(title) and is_map(add) and is_list(remove) do
    BookBankWeb.Utils.with(conn, [authentication: ["librarian", "admin"]], fn conn, _extra ->
      obj =
        if Enum.all?(add, fn
             {k, v} when is_binary(k) and is_binary(v) -> true
             _ -> false
           end) and Enum.all?(remove, &is_binary/1) do
          remove_list = Enum.map(remove, &({:remove, &1}))
          add_list = Enum.map(add, fn {k, v} -> {:update, k, v} end)
          case BookBank.MongoDatabase.update_book(id, remove_list ++ add_list) do
            {:error, :does_not_exist} -> {:error, :not_found, "No such book with id '#{id}'."}
            {:error, str} -> {:error, :internal_server_error, str}
          end
        else
          {:error, :bad_request, "'add' must be { [string]: string } and 'remove' must be string[]"}
        end

      {conn, obj}
    end)
  end

  def patch_metadata(conn, %{})
end
