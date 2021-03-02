defmodule BookBankWeb.BooksController do
  use BookBankWeb, :controller

  import BookBank.DI

  def get_book_meta(conn, %{"id" => id}) do
    BookBankWeb.Utils.with(conn, [authentication: :any], fn conn, _extra ->
      obj =
        case database_service().get_book_metadata(id) do
          {:ok, %BookBank.Book{id: id, title: title, metadata: metadata, size: size}} ->
            {:ok, :ok, %{"id" => id, "title" => title, "metadata" => metadata, "size" => size}}

          {:error, :does_not_exist} ->
            {:error, :not_found, "No such book with id '#{id}'"}

          {:error, e} when is_binary(e) ->
            {:error, :internal_server_error, e}
        end

      {conn, obj}
    end)
  end

  def get_book_meta(conn, _params) do
    BookBankWeb.Utils.with(conn, [authentication: :any], fn conn, _extra ->
      {conn, {:error, :not_found}}
    end)
  end

  def get_book_cover(conn, %{"id" => id}) do
    BookBankWeb.Utils.with(conn, [authentication: :any], fn conn, _extra ->
      obj =
        case database_service().get_book_cover(id) do
          {:ok, stream, %BookBank.Book{}} ->
            {:ok, :ok, :stream, stream, disposition: :inline, content_type: "image/jpg"}

          {:error, :does_not_exist} ->
            {:error, :not_found, "No such book with id '#{id}'"}

          {:error, e} when is_binary(e) ->
            {:error, :internal_server_error, e}
        end

      {conn, obj}
    end)
  end

  def get_book_cover(conn, _params) do
    BookBankWeb.Utils.with(conn, [authentication: :any], fn conn, _extra ->
      {conn, {:error, :not_found}}
    end)
  end

  def get_book_thumb(conn, %{"id" => id}) do
    BookBankWeb.Utils.with(conn, [authentication: :any], fn conn, _extra ->
      obj =
        case database_service().get_book_thumb(id) do
          {:ok, stream, %BookBank.Book{}} ->
            {:ok, :ok, :stream, stream, disposition: :inline, content_type: "image/jpg"}

          {:error, :does_not_exist} ->
            {:error, :not_found, "No such book with id '#{id}'"}

          {:error, e} when is_binary(e) ->
            {:error, :internal_server_error, e}
        end

      {conn, obj}
    end)
  end

  def get_book_thumb(conn, _params) do
    BookBankWeb.Utils.with(conn, [authentication: :any], fn conn, _extra ->
      {conn, {:error, :not_found}}
    end)
  end

  defp get_book(conn, %{"id" => id}, disposition) do
    BookBankWeb.Utils.with(conn, [authentication: :any], fn conn, _extra ->
      obj =
        case database_service().get_book_file(id) do
          {:ok, stream, %BookBank.Book{title: title}} ->
            disposition =
              case disposition do
                :inline -> :inline
                :attachment -> {:attachment, "#{title}.pdf"}
              end

            {:ok, :ok, :stream, stream,
             [disposition: disposition, content_type: "application/pdf"]}

          {:error, :does_not_exist} ->
            {:error, :not_found, "No such book with id '#{id}'"}

          {:error, e} when is_binary(e) ->
            {:error, :internal_server_error, e}
        end

      {conn, obj}
    end)
  end

  def get_book_download(conn, %{"id" => _} = params) do
    get_book(conn, params, :attachment)
  end

  def get_book_download(conn, _params) do
    BookBankWeb.Utils.with(conn, [authentication: :any], fn conn, _extra ->
      {conn, {:error, :not_found}}
    end)
  end

  def get_book_view(conn, %{"id" => _} = params) do
    get_book(conn, params, :inline)
  end

  def get_book_view(conn, _params) do
    BookBankWeb.Utils.with(conn, [authentication: :any], fn conn, _extra ->
      {conn, {:error, :not_found}}
    end)
  end

  @spec post_upload(Plug.Conn.t(), %{String.t() => term()}) :: Plug.Conn.t()
  def post_upload(conn, %{
        "title" => title,
        "book" => %Plug.Upload{content_type: "application/pdf", path: path}
      })
      when is_binary(title) do
    BookBankWeb.Utils.with(conn, [authentication: ["librarian", "admin"]], fn conn, _extra ->
      obj =
        case database_service().create_book(title, File.stream!(path, [], 4096), %{}) do
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
        "This endpoint requires a multipart/form-data request body with a string 'title' and a application/pdf upload 'book'."}}
    end)
  end

  def put_metadata_params_update_list([], acc) do
    if acc == [] do
      {:error, "'title' and/or 'metadata' must be set."}
    else
      {:ok, acc}
    end
  end

  def put_metadata_params_update_list([head | tail], acc) do
    case head do
      {"title", title} when is_binary(title) ->
        put_metadata_params_update_list(tail, [{:update_title, title} | acc])

      {"title", _} ->
        {:error, "'title' must be a string"}

      {"metadata", metadata} when is_map(metadata) ->
        if Enum.all?(metadata, fn
             {k, v} when is_binary(k) and is_binary(v) -> true
             _ -> false
           end) do
          put_metadata_params_update_list(tail, [
            {:set_metadata, metadata |> Enum.map(fn {k, v} -> %{"key" => k, "value" => v} end)}
            | acc
          ])
        else
          {:error, "'metadata' must be { [string]: string }"}
        end

      {"metadata", metadata} when is_list(metadata) ->
        if Enum.all?(metadata, fn
             %{"key" => key, "value" => value} when is_binary(key) and is_binary(value) -> true
             _ -> false
           end) do
          put_metadata_params_update_list(tail, [{:set_metadata, metadata} | acc])
        end

      {"metadata", _} ->
        {:error, "'metadata' must be { [string]: string } or { key: string, value: string }[]"}

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
        case put_metadata_params_update_list(params) do
          {:ok, update_list} ->
            case database_service().update_book(id, update_list) do
              :ok -> {:ok, :ok}
              {:error, :does_not_exist} -> {:error, :not_found, "No such book with id #{id}"}
              {:error, str} -> {:error, :internal_server_error, str}
            end

          {:error, e} ->
            {:error, :bad_request, e}
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
    if acc === [] do
      {:error, "'title', 'add', or 'remove' must be given."}
    else
      {:ok, acc}
    end
  end

  def patch_metadata_params_update_list([head | tail], acc) do
    acc =
      case head do
        {"title", title} when is_binary(title) ->
          [{:update_title, title} | acc]

        {"title", _} ->
          {:error, "'title' must be a string."}

        {"add", add} when is_map(add) ->
          if Enum.all?(add, fn {k, v} -> is_binary(k) and is_binary(v) end) do
            [{:update_metadata, add} | acc]
          else
            {:error, "All metadata values must be strings"}
          end

        {"add", add} when is_list(add) ->
          if Enum.all?(add, fn
               %{"key" => k, "value" => v} when is_binary(k) and is_binary(v) -> true
               _ -> false
             end) do
            [
              {:update_metadata,
               add |> Enum.map(fn %{"key" => k, "value" => v} -> {k, v} end) |> Map.new()}
              | acc
            ]
          end

        {"add", _} ->
          {:error, "'add' must be { [string]: string }"}

        {"remove", remove} when is_list(remove) ->
          if Enum.all?(remove, &is_binary/1) do
            [{:remove, remove} | acc]
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
        case patch_metadata_params_update_list(params) do
          {:ok, update_list} ->
            case database_service().update_book(id, update_list) do
              :ok -> {:ok, :ok}
              {:error, :does_not_exist} -> {:error, :not_found, "No such book with id '#{id}'."}
              {:error, str} -> {:error, :internal_server_error, str}
            end

          {:error, e} ->
            {:error, :bad_request, e}
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
      obj =
        case database_service().delete_book(id) do
          :ok -> {:ok, :ok}
          {:error, :does_not_exist} -> {:error, :not_found, "No such book with id #{id}."}
          {:error, e} when is_binary(e) -> {:error, :internal_server_error, e}
        end

      {conn, obj}
    end)
  end

  def delete_book(conn, _params) do
    BookBankWeb.Utils.with(conn, [authentication: ["librarian", "admin"]], fn conn, _extra ->
      {conn, {:error, :not_found}}
    end)
  end
end
