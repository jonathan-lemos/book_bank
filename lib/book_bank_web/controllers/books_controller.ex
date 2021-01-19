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
      {"title", title} when is_binary(title) ->
        put_metadata_params_update_list(tail, [{:set_title, title} | acc])

      {"title", _} ->
        {:error, "'title' must be a string"}

      {"metadata", metadata} when is_map(metadata) ->
        if Enum.all?(metadata, fn
             {k, v} when is_binary(k) and is_binary(v) -> true
             _ -> false
           end) do
          put_metadata_params_update_list(tail, [{:replace_metadata, metadata} | acc])
        else
          {:error, "'metadata' must be { [string]: string }"}
        end

      {"metadata", _} ->
        {:error, "'metadata' must be { [string]: string }"}

      _ ->
        put_metadata_params_update_list(tail, acc)
    end
  end

  def put_metadata_params_update_list(params) when is_map(params) do
    put_metadata_params_update_list(Map.to_list(params), [])
  end

  def put_metadata(conn, %{"id" => id} = params) when is_binary(id) do
    BookBankWeb.Utils.with(conn, [authentication: ["librarian", "admin"]], fn conn, _extra ->
      obj =
        with {:ok, update_list} <- put_metadata_params_update_list(params) do
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

  def put_metadata(conn, _params) do
    BookBankWeb.Utils.with(conn, [authentication: ["librarian", "admin"]], fn conn, _extra ->
      {conn, {:error, :not_found}}
    end)
  end

  def patch_metadata_params_update_list([], acc) do
    if length(acc) == 0 do
      {:error, "'title', 'add', or 'remove' must be given."}
    else
      {:ok, acc}
    end
  end

  def patch_metadata_params_update_list([head | tail], acc) do
    acc =
      case head do
        {"title", title} when is_binary(title) ->
          [{:set_title, title} | acc]

        {"title", _} ->
          {:error, "'title' must be a string."}

        {"add", add} when is_map(add) ->
          Enum.reduce(add, [], fn
            _, {:error, s} -> {:error, s}
            {k, v}, acc when is_binary(k) and is_binary(v) -> [{:update, k, v} | acc]
            _, _ -> {:error, "'metadata' values must all be strings"}
          end) ++ acc

        {"add", _} ->
          {:error, "'add' must be { [string]: string }"}

        {"remove", remove} when is_list(remove) ->
          if Enum.all?(remove, &is_binary/1) do
            [{:remove} | acc]
          end

        {"remove", _} ->
          {:error, "'remove' must be string[]"}

        _ ->
          acc
      end

    case acc do
      {:error, _} = e -> e
      l when is_list(l) -> patch_metadata_params_update_list(tail, l)
    end
  end

  def patch_metadata_params_update_list(params) when is_map(params) do
    patch_metadata_params_update_list(Map.to_list(params), [])
  end

  def patch_metadata(conn, %{"id" => id} = params) when is_binary(id) do
    BookBankWeb.Utils.with(conn, [authentication: ["librarian", "admin"]], fn conn, _extra ->
      obj =
        with {:ok, update_list} <- patch_metadata_params_update_list(params) do
          case BookBank.MongoDatabase.update_book(id, update_list) do
            {:error, :does_not_exist} -> {:error, :not_found, "No such book with id '#{id}'."}
            {:error, str} -> {:error, :internal_server_error, str}
          end
        else
          {:error, e} -> {:error, :bad_request, e}
        end

      {conn, obj}
    end)
  end

  def patch_metadata(conn, _params) do
    BookBankWeb.Utils.with(conn, [authentication: ["librarian", "admin"]], fn conn, _extra ->
      {conn, {:error, :not_found}}
    end)
  end

  def delete_book(conn, %{"id" => id}) do
    BookBankWeb.Utils.with(conn, [authentication: ["librarian", "admin"]], fn conn, _extra ->
      BookBank.MongoDatabase.delete_book(id) do

      end
    end)
  end
end
