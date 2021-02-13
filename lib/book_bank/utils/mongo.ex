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

  def prepare_document(%{__struct__: _} = doc) do
    doc
  end

  def prepare_document(doc) when is_map(doc) do
    doc
    |> Stream.map(fn {key, value} ->
      key =
        cond do
          is_atom(key) -> Atom.to_string(key)
          is_binary(key) -> key
          true -> raise ArgumentError, message: "Keys of a document must be strings or atoms, got #{Kernel.inspect(key)}"
        end

      value = if key === "_id" and is_binary(value) do
        value |> BSON.ObjectId.decode!()
      else
        value |> prepare_document()
      end

      value = prepare_document(value)

      {key, value}
    end)
    |> Map.new()
  end

  def prepare_document(doc) do
    doc
  end

  def is_kvpmap(map) do
    is_map(map) and
      map |> Enum.all?(fn e -> match?({k, v} when is_binary(k) and is_binary(v), e) end)
  end

  def is_kvplist(list) do
    is_list(list) and
      list |> Enum.all?(fn e ->
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
    case kvpmap_to_kvplist(map) do
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

  @spec find(
          String.t(),
          map(),
          list(
            {:retry_count, non_neg_integer()}
            | {:read_concern, read_concern()}
          )
        ) :: {:ok, map()} | {:error, :does_not_exist | String.t()}
  def find(collection, filter, opts \\ []) do
    retry_count = opts[:retry_count] || 2
    read_concern = opts[:read_concern] || read_concern_local()

    result =
      case Mongo.find_one(:mongo, collection, filter |> prepare_document(), read_concern: read_concern) do
        doc when is_map(doc) ->
          {:ok, doc |> Map.put("_id", doc["_id"] |> BSON.ObjectId.encode!())}

        nil ->
          {:error, :does_not_exist}

        {:error, %Mongo.Error{message: message, retryable_reads: true}} ->
          {:retry, message}

        {:error, %Mongo.Error{message: message}} ->
          {:error, message}

        e ->
          {:error, "Malformed response from the server: #{Kernel.inspect(e)}."}
      end

    case result do
      {:ok, res} ->
        {:ok, res}

      {:retry, msg} ->
        if retry_count > 0 do
          find(collection, filter, opts |> Keyword.merge(retry_count: retry_count - 1))
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
      case Mongo.insert_one(:mongo, collection, object |> prepare_document(), write_concern: write_concern) do
        {:ok, %Mongo.InsertOneResult{acknowledged: true, inserted_id: id}} ->
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

  @spec replace(
          String.t(),
          String.t(),
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
      case Mongo.replace_one(:mongo, collection, %{_id: id |> BSON.ObjectId.decode!()}, new_object |> Map.merge(%{_id: id}) |> prepare_document(),
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
      :ok ->
        :ok

      {:retry, msg} ->
        if retry_count > 0 do
          replace(collection, id, new_object, opts |> Keyword.merge(retry_count: retry_count - 1))
        else
          {:error, msg}
        end

      {:error, msg} ->
        {:error, msg}
    end
  end

  @spec delete(
          String.t(),
          map(),
          list(
            {:retry_count, non_neg_integer()}
            | {:write_concern, write_concern()}
          )
        ) ::
          {:ok, map()} | {:error, :does_not_exist | String.t()}
  def delete(collection, filter, opts \\ []) do
    retry_count = opts[:retry_count] || 2
    write_concern = opts[:write_concern] || write_concern_2()

    result =
      case Mongo.find_one_and_delete(:mongo, collection, filter |> prepare_document(), write_concern: write_concern) do
        {:ok, doc} ->
          {:ok, doc}

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
          delete(collection, filter, opts |> Keyword.merge(retry_count: retry_count - 1))
        else
          {:error, msg}
        end

      {:error, msg} ->
        {:error, msg}
    end
  end

  @spec insert_file(Stream.t(), String.t(), String.t()) ::
          {:ok, BSON.ObjectId.t(), non_neg_integer()} | {:error, String.t()}
  def insert_file(file_stream, filename, bucket_name \\ "fs") do
    bucket = Mongo.GridFs.Bucket.new(:mongo, name: bucket_name)
    upload_stream = Mongo.GridFs.Upload.open_upload_stream(bucket, filename)

    size =
      file_stream
      |> Stream.into(upload_stream)
      |> Enum.reduce(0, fn chunk, acc -> acc + byte_size(chunk) end)

    {:ok, upload_stream.id, size}
  end

  @spec download_file(BSON.ObjectId.t(), String.t()) ::
          {:ok, Stream.t()} | {:error, :does_not_exist | String.t()}
  def download_file(id, bucket_name \\ "fs") do
    bucket = Mongo.GridFs.Bucket.new(:mongo, name: bucket_name)

    case Mongo.GridFs.Download.open_download_stream(bucket, id) do
      {:ok, stream} -> {:ok, stream}
      {:error, :not_found} -> {:error, :does_not_exist}
      {:error, _} -> {:error, "Failed to fetch the document."}
    end
  end

  @spec delete_file(BSON.ObjectId.t(), String.t(), list({:retry_count, non_neg_integer()})) ::
          :ok | {:error, :does_not_exist | String.t()}
  def delete_file(id, bucket_name \\ "fs", opts \\ []) do
    retry_count = opts[:retry_count] || 2
    bucket = Mongo.GridFs.Bucket.new(:mongo, name: bucket_name)

    result =
      case Mongo.GridFs.Bucket.delete(bucket, id) do
        {:ok, %Mongo.DeleteResult{acknowledged: true, deleted_count: n}} when n > 0 ->
          :ok

        {:ok, %Mongo.DeleteResult{acknowledged: true, deleted_count: 0}} ->
          {:error, :does_not_exist}

        {:ok, %Mongo.DeleteResult{acknowledged: false}} ->
          {:error, "The delete was not acknowledged."}

        {:error, %Mongo.Error{message: message, retryable_writes: true}} ->
          {:retry, message}

        {:error, %Mongo.Error{message: message}} ->
          {:error, message}
      end

    case result do
      :ok ->
        :ok

      {:retry, msg} ->
        if retry_count > 0 do
          delete_file(id, bucket_name, retry_count: retry_count - 1)
        else
          {:error, msg}
        end

      {:error, msg} ->
        {:error, msg}
    end
  end

  defp remove_documents(inserted) do
    error_message =
      inserted
      |> Enum.map(fn {_path, id, bucket, _size} -> fn -> {id, bucket, delete_file(id, bucket)} end end)
      |> BookBank.Utils.Parallel.invoke()
      |> Enum.filter(fn {_id, _bucket, tuple} -> match?({:error, _}, tuple) end)
      |> Enum.map(fn {id, bucket, {:error, e}} ->
        "Failed to remove file #{id} from bucket #{bucket}: #{e}"
      end)
      |> Enum.join(", ")

    if error_message === "" do
      :ok
    else
      {:error, error_message}
    end
  end

  defp put_deep(document, [head], term) do
    document |> Map.put(head, term)
  end

  defp put_deep(document, [head | tail], term) do
    document |> Map.put(head, document |> Map.get(head, %{}) |> put_deep(tail, term))
  end

  defp insert_with_files(collection, document, [], inserted) do
    document =
      inserted
      |> Enum.reduce(document, fn {path, id, bucket, _size}, acc ->
        acc |> put_deep(path, %{"gridfs_id" => id, "bucket" => bucket})
      end)

    case insert(collection, document) do
      {:ok, id_result} ->
        {:ok, id_result}

      {:error, msg} ->
        case remove_documents(inserted) do
          :ok ->
            {:error, "Failed to insert document: #{msg}"}

          {:error, removal_message} ->
            {:inconsistent,
             "Failed to insert document: #{msg}, Also failed to remove the inserted files: #{
               removal_message
             }"}
        end
    end
  end

  defp insert_with_files(
         collection,
         document,
         [{path, stream, filename, bucket} | tail],
         inserted
       ) do
    case insert_file(stream, filename, bucket) do
      {:ok, id, size} ->
        insert_with_files(collection, document, tail, [
          {path, id, bucket, size} | inserted
        ])

      {:error, message} ->
        case remove_documents(inserted) do
          :ok ->
            {:error, message}

          {:error, removal_message} ->
            {:inconsistent,
             "Failed to insert file #{filename} into #{bucket}: #{message}, Also failed to remove the inserted files: #{
               removal_message
             }"}
        end
    end
  end

  @spec insert_with_files(
          String.t(),
          map(),
          list({list(String.t()), Stream.t(), String.t(), String.t()})
        ) :: {:ok, String.t()} | {:error, String.t()}
  def insert_with_files(collection, document, files) do
    insert_with_files(collection, document, files, [])
  end

  defp delete_files_from_document(%{"gridfs_id" => id, "bucket" => bucket}) do
    case delete_file(id, bucket) do
      :ok -> :ok
      {:error, e} -> {:error, "Failed to delete file #{id} from bucket #{bucket}: #{e}"}
    end
  end

  defp delete_files_from_document(doc) when is_map(doc) do
    errors =
      doc
      |> Enum.map(fn {key, _value} -> delete_files_from_document(doc[key]) end)
      |> Enum.filter(&match?({:error, _e}, &1))

    if length(errors) > 0 do
      {:error, errors |> Enum.join(", ")}
    else
      :ok
    end
  end

  defp delete_files_from_document(_) do
    :ok
  end

  @spec delete_with_files(String.t(), map()) :: :ok | {:error, String.t()}
  def delete_with_files(collection, filter) do
    with {:ok, doc} <- delete(collection, filter) do
      delete_files_from_document(doc)
    else
      e -> e
    end
  end

  defp get_file(%{"gridfs_id" => id, "bucket" => bucket}, []) do
    {:ok, id, bucket}
  end

  defp get_file(_obj, []) do
    {:error, "The path does not point to a {gridfs_id: ObjectID, bucket: string} object."}
  end

  defp get_file(map, [head | tail]) when is_map(map) do
    map |> Map.get(head) |> get_file(tail)
  end

  defp get_file(_, _) do
    {:error, "The given path does not exist in the document."}
  end

  @spec find_file(
          String.t(),
          map(),
          list(String.t()),
          list({:retry_count, non_neg_integer()} | {:read_concern, read_concern()})
        ) :: {:ok, Stream.t()} | {:error, :does_not_exist | String.t()}
  def find_file(collection, filter, path, opts \\ []) do
    with {:ok, doc} <- find(collection, filter, opts),
         {:ok, id, bucket} <- get_file(doc, path) do
      case download_file(id, bucket) do
        {:ok, stream} -> {:ok, stream, doc}
        {:error, e} -> {:error, e}
      end
    else
      e -> e
    end
  end
end
