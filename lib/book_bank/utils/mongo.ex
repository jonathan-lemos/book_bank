defmodule BookBank.Utils.Mongo do
  @dialyzer {:no_contracts, :"init/0"}
  def init() do
    Mongo.create_indexes(:mongo, "books", [
      [[key: [metadata: [key: 1]], unique: true]]
    ])

    Mongo.create_indexes(:mongo, "users", [[key: [username: 1], unique: true]])

    :ok
  end

  @type read_concern :: %{level: String.t()}
  @type write_concern :: %{w: non_neg_integer() | String.t()}

  @doc """
  A read concern specifying that data should be read from a single node regardless of how many nodes have acknowledged the data.
  """
  def read_concern_local() do
    %{level: "local"}
  end

  @doc """
  A read concern ensuring that a majority of the nodes have acknowledged the changes sent.
  """
  def read_concern_majority() do
    %{level: "majority"}
  end

  @doc """
  A write concern ensuring that a majority of the nodes have acknowledged the write.
  """
  def write_concern_majority(timeout_ms \\ 10000) when timeout_ms >= 0 do
    %{w: "majority", j: true, wtimeout: timeout_ms}
  end

  @doc """
  A write concern ensuring that at least one node has acknowledged the write.
  """
  def write_concern_1(timeout_ms \\ 10000) when timeout_ms >= 0 do
    %{w: 1, j: true, wtimeout: timeout_ms}
  end

  @doc """
  A write concern ensuring that at least two nodes have acknowledged the write.
  """
  def write_concern_2(timeout_ms \\ 10000) when timeout_ms >= 0 do
    %{w: 2, j: true, wtimeout: timeout_ms}
  end

  @doc """
  A write concern ensuring that at least three nodes have acknowledged the write.
  """
  def write_concern_3(timeout_ms \\ 10000) when timeout_ms >= 0 do
    %{w: 3, j: true, wtimeout: timeout_ms}
  end

  def is_kvpmap(map) do
    is_map(map) and Enum.all?(fn e -> match?({k, v} when is_binary(k) and is_binary(v), e) end)
  end

  def is_kvplist(list) do
    is_list(list) and
      Enum.all?(fn e ->
        match?(%{"key" => k, "value" => v} when is_binary(k) and is_binary(v), e)
      end)
  end

  def kvpmap_to_kvplist(map) do
    if is_kvpmap(map) do
      {:ok, map |> Enum.map(fn {k, v} -> %{"key" => k, "value" => v} end)}
    else
      :error
    end
  end

  def kvpmap_to_kvplist!(map) do
    case kvplist_to_kvpmap(map) do
      {:ok, list} -> list
      :error -> raise ArgumentError, message: "The argument was not a %{String.t() => String.t()}"
    end
  end

  def kvplist_to_kvpmap(list) do
    if is_kvplist(list) do
      {:ok, list |> Map.new(fn %{"key" => k, "value" => v} -> {k, v} end)}
    else
      :error
    end
  end

  def kvplist_to_kvpmap!(list) do
    case kvplist_to_kvpmap(list) do
      {:ok, map} -> map
      :error -> raise ArgumentError, message: "The argument was not a key-value-pair list."
    end
  end

  defp object_merge_list([head | tail], accumulator_list, accumulator_existing) do
    if accumulator_existing |> MapSet.member?(head) do
      object_merge_list(tail, accumulator_list, accumulator_existing)
    else
      object_merge_list(tail, [head | accumulator_list], accumulator_existing |> MapSet.put(head))
    end
  end

  defp object_merge_list([], acc, _existing) do
    acc
  end

  defp object_merge_lists(a, b) do
    object_merge_list(b, a |> Enum.reverse(), a |> MapSet.new()) |> Enum.reverse()
  end

  defp object_merge_map([{key, value} | tail], acc) do
    if acc |> Map.has_key?(key) do
      object_merge_map(tail, Map.put(acc, key, object_merge(acc |> Map.get(key), value)))
    else
      object_merge_map(tail, Map.put(acc, key, value))
    end
  end

  defp object_merge_map([], acc) do
    acc
  end

  defp object_merge_maps(a, b) do
    object_merge_map(b |> Enum.map(& &1), a)
  end

  def object_merge(a, b) do
    cond do
      is_map(a) and is_map(b) -> object_merge_maps(a, b)
      is_list(a) and is_list(b) -> object_merge_lists(a, b)
      true -> b
    end
  end

  @spec find_one(
          String.t(),
          map(),
          list(
            {:retry_count, non_neg_integer()}
            | {:read_concern, read_concern()}
          )
        ) :: {:ok, map()} | {:error, :does_not_exist | String.t()}
  def find_one(collection, filter, opts \\ []) do
    retry_count = opts[:retry_count] || 2
    read_concern = opts[:read_concern] || read_concern_local()

    case Mongo.find_one(:mongo, collection, filter, read_concern: read_concern) do
      doc when is_map(doc) ->
        {:ok, doc}

      nil ->
        {:error, :does_not_exist}

      {:error, %Mongo.Error{message: message, retryable_reads: true}} ->
        {:retry, message}

      {:error, %Mongo.Error{message: message}} ->
        {:error, message}

      _ ->
        {:error, "Malformed response from the server."}
    end

    case result do
      {:ok, res} ->
        {:ok, res}

      {:retry, _msg} ->
        if retry_count > 0 do
          find_one(collection, object, opts |> Keyword.merge(retry_count: retry_count - 1))
        else
          {:error, msg}
        end

      {:error, msg} ->
        {:error, msg}
    end
  end

  @spec insert(
          String.t(),
          map(),
          non_neg_integer(),
          list(
            {:retry_count, non_neg_integer()}
            | {:write_concern, write_concern()}
          )
        ) ::
          {:ok, String.t()} | {:error, String.t()}
  def insert(collection, object, opts \\ []) do
    retry_count = opts[:retry_count] || 2
    write_concern = opts[:write_concern] || write_concern_2()

    result =
      case Mongo.insert_one(:mongo, collection, object, write_concern: write_concern) do
        {:ok, %Mongo.InsertOneResult{acknowledged: true, inserted_id: id}} when is_binary(id) ->
          {:ok, BSON.ObjectId.encode!(id)}

        {:ok, %Mongo.InsertOneResult{acknowledged: true}} ->
          {:error, "An object with the given ID already exists."}

        {:ok, %Mongo.InsertOneResult{}} ->
          {:error, "The write was not acknowledged."}

        {:error, %Mongo.Error{message: message, retryable_writes: true}} ->
          {:retry, message}

        {:error, %Mongo.Error{message: message}} ->
          {:error, message}
      end

    case result do
      {:ok, res} ->
        {:ok, res}

      {:retry, msg} ->
        if retry_count > 0 do
          insert(collection, object, opts |> Keyword.merge(retry_count: retry_count - 1))
        else
          {:error, msg}
        end

      {:error, msg} ->
        {:error, msg}
    end
  end

  @spec insert(
          String.t(),
          id,
          map,
          list(
            {:retry_count, non_neg_integer()}
            | {:write_concern, write_concern()}
          )
        ) :: :ok | {:error, :does_not_exist | String.t()}
  def replace(
        collection,
        id,
        new_object,
        opts \\ []
      ) do
    retry_count = opts[:retry_count] || 2
    write_concern = opts[:write_concern] || write_concern_2()

    result =
      case Mongo.replace_one(:mongo, collection, %{_id: id}, new_object |> Map.merge(%{_id: id}),
             write_concern: write_concern
           ) do
        {:ok, %Mongo.UpdateResult{acknowledged: true, matched_count: n}} when n > 0 ->
          :ok

        {:ok, %Mongo.UpdateResult{acknowledged: true, matched_count: 0}} ->
          {:error, :does_not_exist}

        {:ok, %Mongo.UpdateResult{}} ->
          {:error, "The write was not acknowledged."}

        {:error, %Mongo.Error{message: message, retryable_writes: true}} ->
          {:retry, message}

        {:error, %Mongo.Error{message: message}} ->
          {:error, message}
      end

    case result do
      {:ok, res} ->
        {:ok, res}

      {:retry, msg} ->
        if retry_count > 0 do
          replace(collection, id, new_object, retry_count - 1, write_concern)
        else
          {:error, msg}
        end

      {:error, msg} ->
        {:error, msg}
    end
  end

  @spec delete(
          String.t(),
          id,
          list(
            {:retry_count, non_neg_integer()}
            | {:write_concern, write_concern()}
          )
        ) ::
          :ok | {:error, :does_not_exist | String.t()}
  def delete(collection, id, opts \\ []) do
    retry_count = opts[:retry_count] || 2
    write_concern = opts[:write_concern] || write_concern_2()

    result =
      case Mongo.delete_many(:mongo, collection, %{_id: id}, write_concern: write_concern) do
        {:ok, %Mongo.DeleteResult{acknowledged: true, deleted_count: n}} when n > 0 ->
          :ok

        {:ok, %Mongo.DeleteResult{acknowledged: true, deleted_count: 0}} ->
          {:error, :does_not_exist}

        {:ok, %Mongo.DeleteResult{}} ->
          {:error, "The delete was not acknowledged."}

        {:error, %Mongo.Error{message: message, retryable_writes: true}} ->
          {:retry, message}

        {:error, %Mongo.Error{message: message}} ->
          {:error, message}
      end

    case result do
      {:ok, res} ->
        {:ok, res}

      {:retry, msg} ->
        if retry_count > 0 do
          delete(collection, id, retry_count - 1, write_concern)
        else
          {:error, msg}
        end

      {:error, msg} ->
        {:error, msg}
    end
  end
end
