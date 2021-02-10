defmodule BookBank.ElasticSearch do
  @behaviour BookBank.SearchBehavior

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

  defp hit_endpoint(method, endpoint, body \\ nil) do
    with {:ok, json} <- Jason.encode(body) do
      case HTTPoison.request(method, es_url(endpoint), json, [
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
        {:error, "Failed to encode the body '#{Kernel.inspect(body)}' as JSON: #{e.message}"}

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
      val =
        obj["hits"]["hits"]
        |> Enum.map(fn x ->
          src = x["_source"]

          %{
            id: src["id"],
            title: src["title"],
            metadata:
              src["metadata"]
              |> Enum.map(fn %{"key" => key, "value" => value} -> {key, value} end)
              |> Map.new()
          }
        end)

      {:ok, val}
    else
      {:error, "Malformed response from Elasticsearch instance."}
    end
  end

  @impl true
  def search(query, count, page) do
    with {:ok, size} <- BookBankWeb.Validation.validate_integer(count, lower: 1),
         {:ok, page} <- BookBankWeb.Validation.validate_integer(page, lower: 0) do
      from = page * size

      case hit_endpoint(:get, "/_search", %{
             query: %{
               multi_match: %{
                 query: query,
                 fields: ["title", "metadata.value^2"],
                 fuzziness: "AUTO",
                 _source: ["id", "title", "metadata"],
                 sort: [
                   %{"_score" => "desc"},
                   %{"title" => "asc"}
                 ]
               }
             },
             size: size,
             from: from
           }) do
        {:ok, obj} ->
          case format_hits(obj) do
            {:ok, hits} -> {:ok, %{"results" => hits}}
          end

        {:error, msg} ->
          {:error, msg}
      end
    else
      {:error, e} -> {:error, e}
    end
  end

  @impl true
  def search_count(query) do
    case hit_endpoint(:get, "/_count", %{
           query: %{
             multi_match: %{
               query: query,
               fields: ["title", "metadata.value^2"],
               fuzziness: "AUTO"
             }
           }
         }) do
      {:ok, %{"count" => count}} when count >= 0 ->
        {:ok, count}

      {:ok, obj} ->
        {:error, "Malformed response from Elasticsearch: #{Kernel.inspect(obj)}"}

      {:error, e} ->
        {:error, e}
    end
  end

  @impl true
  def insert_book(%BookBank.Book{id: id, title: title, metadata: metadata}) do
    case hit_endpoint(:put, "/books/_create/#{id}", %{
           "id" => id,
           "title" => title,
           "metadata" => metadata |> BookBank.Utils.Mongo.kvpmap_to_kvplist!()
         }) do
      {:ok, %{"result" => "created"}} ->
        :ok

      {:ok, e} ->
        {:error, "Bad response from Elasticsearch: #{Kernel.inspect(e)}"}

      {:error, e} ->
        {:error, e}
    end
  end

  @impl true
  def update_book(%BookBank.Book{id: id, title: title, metadata: metadata}) do
    case hit_endpoint(:put, "/books/_doc/#{id}", %{
           "id" => id,
           "title" => title,
           "metadata" => metadata |> BookBank.Utils.Mongo.kvpmap_to_kvplist!()
         }) do
      {:ok, %{"result" => "updated"}} ->
        :ok

      {:ok, e} ->
        {:error, "Bad response from Elasticsearch: #{Kernel.inspect(e)}"}

      {:error, e} ->
        {:error, e}
    end
  end

  @impl true
  def delete_book(id) do
    case hit_endpoint(:delete, "/books/_doc/#{id}") do
      {:ok, %{"result" => "deleted"}} ->
        :ok

      {:ok, e} ->
        {:error, "Bad response from Elasticsearch: #{Kernel.inspect(e)}"}

      {:error, e} ->
        {:error, e}
    end
  end
end
