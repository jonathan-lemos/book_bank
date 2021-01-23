defmodule BookBankWeb.SearchController do
  use BookBankWeb, :controller

  defp es_url(endpoint) do
    base =
      Application.get_env(:book_bank, BookBankWeb.SearchController, :url)
      |> String.trim_trailing("/")

    index = Application.get_env(:book_bank, BookBankWeb.SearchController, :index)
    base <> "/" <> index <> "/" <> (endpoint |> String.trim_leading("/"))
  end

  defp parse_response(status, body) do
    if div(status, 100) !== 2 do
      {:error, status, "The Elastic Search response was not 2XX. Response: '#{body}'"}
    else
      status = BookBankWeb.Utils.status_code_to_atom(status)

      case Jason.decode(body) do
        {:ok, term} ->
          {:ok, status, term}

        {:error, _} ->
          {:error, status, "The Elasticsearch response '#{body}' was not valid JSON."}
      end
    end
  end

  defp post_endpoint(endpoint, body) do
    with {:ok, json} <- Jason.encode(body) do
      case HTTPoison.post(es_url(endpoint), json, [
             {"Accept", "application/json"},
             {"Content-Type", "application/json"}
           ]) do
        {:ok, %HTTPoison.Response{body: body, status_code: status}} ->
          parse_response(status, body)

        {:error, %HTTPoison.Error{reason: r}} ->
          r =
            case r do
              r when is_atom(r) -> Atom.to_string(r)
              r -> r
            end

          {:error, :internal_server_error,
           "Failed to connect to the Elasticsearch instance: #{r}"}
      end
    else
      {:error, e} ->
        {:error, "Failed to encode the body '#{IO.inspect(body)}' as JSON: #{e.message}"}

      e ->
        {:error, e.message}
    end
  end

  defp format_hits(obj) do
    if BookBankWeb.Validation.validate_schema(obj, %{
         "hits" => %{
           "hits" =>
             {:list,
              %{
                "_source" =>
                  {:list,
                   %{
                     "id" => :string,
                     "title" => :string,
                     "metadata" =>
                       {:list,
                        %{
                          "key" => :string,
                          "value" => :string
                        }}
                   }}
              }}
         }
       }) do
      val = obj["hits"]["hits"]
      |> Enum.map(fn x ->
        src = x["_source"]
        %{"id" => src["id"], "title" => src["title"], "metadata" => src["metadata"]}
      end)
      {:ok, val}
    else
      {:error, "Malformed response from Elasticsearch instance."}
    end
  end

  def get_query(conn, %{query: query, count: count, page: page}) do
    BookBankWeb.Utils.with(conn, [authentication: :any], fn conn, _extra ->
      obj =
        with {:ok, size} <- BookBankWeb.Validation.validate_integer(count, lower: 1),
             {:ok, page} <- BookBankWeb.Validation.validate_integer(page, lower: 0) do
          from = page * size

          case post_endpoint("/_search", %{
                 query: %{
                   multi_match: %{
                     query: query,
                     fields: ["title", "metadata.value^2"],
                     fuzziness: "AUTO",
                     _source: ["id", "title", "metadata"]
                   }
                 },
                 size: size,
                 from: from
               }) do
            {:ok, status, obj} ->
              case format_hits(obj) do
                {:ok, hits} -> {:ok, status, %{"results" => hits}}
              end

            {:error, status, msg} ->
              {:error, status, msg}
          end
        else
          {:error, e} -> {:error, :bad_request, e}
        end

      {conn, {obj}}
    end)
  end

  def get_query(conn, %{query: query, count: count}) do
    get_query(conn, %{query: query, count: count, page: 0})
  end

  def get_query(conn, %{query: query, page: page}) do
    get_query(conn, %{query: query, count: 10, page: page})
  end

  def get_query(conn, %{query: query}) do
    get_query(conn, %{query: query, count: 10, page: 0})
  end

  def get_count(conn, %{query: query}) do
    BookBankWeb.Utils.with(conn, [authentication: :any], fn conn, _extra ->
      obj =
        case post_endpoint("/_search", %{
               query: %{
                 multi_match: %{
                   query: query,
                   fields: ["title", "metadata.value^2"],
                   fuzziness: "AUTO",
                   sort: [
                     %{"_score" => "desc"},
                     %{"title" => "asc"}
                   ]
                 }
               }
             }) do
          {:ok, status, %{"count" => count}} when count >= 0 ->
            {:ok, status, %{"count" => count}}

          {:ok, _status, obj} ->
            {:error, :internal_server_error,
             %{"response" => "Malformed response from Elasticsearch: #{IO.inspect(obj)}"}}

          {:error, status, e} ->
            {:error, status, e}
        end
      {conn, obj}
    end)
  end
end
