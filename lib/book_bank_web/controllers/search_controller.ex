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

  defp format_hits(status, obj) do
    case obj do
      %{"hits" => %{"hits" => hits}} when is_list(hits) ->
        if Enum.all?(hits, fn hit ->
          case hit do
            %{"_source" => src} when is_map(src) -> true
            _ -> false
          end
        end) do
          docs = Enum.map(hits, fn hit -> case hit["source"] do
            %{"title" => title, "metadata" => metadata} when is_binary(title) and is_list(metadata) ->
              if Enum.all?(metadata, fn kvp ->
                {"key" => key, "value" => value} => true
                _ => false
              end) do
                %{"title" => title, "metadata" => metadata}
              end
            end
          end)
        end
    end
    {:error, status, "Expected a JSON object."}
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
                     fuzziness: "AUTO"
                   }
                 },
                 size: size,
                 from: from
               }) do
            {:ok, status, obj} ->
              {:ok, status,
               %{"results" => Enum.map(obj["hits"]["hits"], fn x -> x["_source"] end)}}

            {:error, status, msg} ->
              {:error, status, msg}
          end
        else
          {:error, e} -> {:error, :bad_request, e}
        end

      {conn, {obj}}
    end)
  end

  def get_count(conn, %{query: query}) do
    obj =
      case post_endpoint("/_search", %{
             query: %{
               multi_match: %{
                 query: query,
                 fields: ["title", "metadata.value^2"],
                 fuzziness: "AUTO"
               }
             }
           }) do
            {:ok, status, obj} ->
              {:ok, status, %{"count" => obj}}
            {:error, status, e} ->
              {:error, status, e}
      end
  end
end
