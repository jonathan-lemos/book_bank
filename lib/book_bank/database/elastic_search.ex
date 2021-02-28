defmodule BookBank.ElasticSearch do
  @behaviour BookBank.SearchBehavior

  defp es_url(endpoint) do
    base =
      Application.get_env(:book_bank, BookBank.ElasticSearch)[:url]
      |> String.trim_trailing("/")

    index = Application.get_env(:book_bank, BookBank.ElasticSearch)[:index]
    base <> "/" <> index <> "/" <> (endpoint |> String.trim_leading("/"))
  end

  defp parse_response(status, body) do
    if div(status, 100) !== 2 do
      {:error, "The Elastic Search response was not 2XX. Response: '#{body}'"}
    else
      case Jason.decode(body) do
        {:ok, term} ->
          {:ok, term}

        {:error, _} ->
          {:error, "The Elasticsearch response '#{body}' was not valid JSON."}
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
                "_source" => %{
                  "id" => :string,
                  "title" => :string,
                  "metadata" =>
                    {:list,
                     %{
                       "key" => :string,
                       "value" => :string
                     }},
                  "size" => :non_neg_integer
                }
              }}
         }
       }) do
      val =
        obj["hits"]["hits"]
        |> Enum.map(fn x ->
          src = x["_source"]

          %BookBank.Book{
            id: src["id"],
            title: src["title"],
            metadata: src["metadata"] |> BookBank.Utils.Mongo.kvplist_to_kvpmap!(),
            size: src["size"]
          }
        end)

      {:ok, val}
    else
      {:error, "Malformed response from Elasticsearch instance."}
    end
  end

  @spec init :: :ok | {:error, String.t()}
  def init() do
    case hit_endpoint(:put, "/", %{
           settings: %{
             analysis: %{
               analyzer: %{
                 autocomplete: %{
                   tokenizer: "lowercase",
                   filter: ["autocomplete_truncate", "autocomplete"]
                 }
               },
               filter: %{
                 autocomplete: %{
                   type: "edge_ngram",
                   min_gram: 3,
                   max_gram: 20
                 },
                 autocomplete_truncate: %{
                   type: "truncate",
                   length: 20
                 }
               }
             }
           }
         }) do
      {:ok, _} ->
        :ok

      {:error, e} ->
        if e |> String.contains?("resource_already_exists_exception") do
          :ok
        else
          {:error, e}
        end
    end
  end

  @impl true
  def search(query, count, page) do
    with {:ok, size} <- BookBankWeb.Validation.validate_integer(count, lower: 1),
         {:ok, page} <- BookBankWeb.Validation.validate_integer(page, lower: 0) do
      from = page * size

      _temp = %{
        query: %{
          multi_match: %{
            query: query,
            fields: ["title", "metadata.value^2"],
            fuzziness: "AUTO"
          }
        },
        sort: [
          "_score"
        ],
        size: size,
        from: from
      }

      case hit_endpoint(:get, "/_search", %{
             query: %{
               multi_match: %{
                 query: query,
                 fields: ["title", "metadata.value^2"],
                 fuzziness: "AUTO",
                 analyzer: "autocomplete"
               }
             },
             sort: [
               "_score"
             ],
             size: size,
             from: from
           }) do
        {:ok, obj} ->
          case format_hits(obj) do
            {:ok, hits} ->
              {:ok, hits}
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
               fuzziness: "AUTO",
               analyzer: "autocomplete"
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
  def insert_book(%BookBank.Book{id: id, title: title, metadata: metadata, size: size}) do
    case hit_endpoint(:post, "/_doc", %{
           "id" => id,
           "title" => title,
           "metadata" => metadata |> BookBank.Utils.Mongo.kvpmap_to_kvplist!(),
           "size" => size
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
  def update_book(%BookBank.Book{id: id, title: title, metadata: metadata, size: size}) do
    case hit_endpoint(:put, "/_doc/#{id}", %{
           "id" => id,
           "title" => title,
           "metadata" => metadata |> BookBank.Utils.Mongo.kvpmap_to_kvplist!(),
           "size" => size
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
    case hit_endpoint(:delete, "/_doc/#{id}") do
      {:ok, %{"result" => "deleted"}} ->
        :ok

      {:ok, e} ->
        {:error, "Bad response from Elasticsearch: #{Kernel.inspect(e)}"}

      {:error, e} ->
        {:error, e}
    end
  end

  def delete_book_index() do
    case hit_endpoint(:delete, "/") do
      {:ok, _} -> :ok
      {:error, e} -> {:error, e}
    end
  end
end
