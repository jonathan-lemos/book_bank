defmodule BookBankWeb.SearchController do
  use BookBankWeb, :controller
  @search_service Application.get_env(:book_bank, :services)[BookBank.SearchBehavior]

  def get_query(conn, %{"query" => query, "count" => count, "page" => page}) do
    BookBankWeb.Utils.with(conn, [authentication: :any], fn conn, _extra ->
      obj =
        with {:ok, count} <- BookBankWeb.Validation.validate_integer(count, lower: 1),
             {:ok, page} <- BookBankWeb.Validation.validate_integer(page, lower: 0) do
          case @search_service.search(query, count, page) do
            {:ok, hits} ->
              {:ok, :ok,
               %{
                 "results" =>
                   hits
                   |> Enum.map(fn %BookBank.Book{
                                    id: id,
                                    metadata: metadata,
                                    size: size,
                                    title: title
                                  } ->
                     %{"id" => id, "metadata" => metadata, "size" => size, "title" => title}
                   end)
               }}

            {:error, e} ->
              {:error, :internal_server_error, e}
          end
        else
          {:error, e} -> {:error, :bad_request, e}
        end

      {conn, obj}
    end)
  end

  def get_query(conn, %{"query" => query, "count" => count}) do
    get_query(conn, %{"query" => query, "count" => count, "page" => 0})
  end

  def get_query(conn, %{"query" => query, "page" => page}) do
    get_query(conn, %{"query" => query, "count" => 10, "page" => page})
  end

  def get_query(conn, %{"query" => query}) do
    get_query(conn, %{"query" => query, "count" => 10, "page" => 0})
  end

  def get_count(conn, %{"query" => query}) do
    BookBankWeb.Utils.with(conn, [authentication: :any], fn conn, _extra ->
      obj =
        case @search_service.count(query) do
          {:ok, count} -> {:ok, :ok, %{"count" => count}}
          {:error, e} -> {:error, :internal_server_error, e}
        end

      {conn, obj}
    end)
  end
end
