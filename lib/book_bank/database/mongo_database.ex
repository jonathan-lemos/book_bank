defmodule BookBank.MongoDatabase do
  @behaviour BookBank.Database

  def create_book(title, body, metadata) do
    bucket = Mongo.GridFs.Bucket.new(:mongo)
    upload_stream = Mongo.GridFs.Upload.open_upload_stream(bucket, "#{title}.pdf")

    body |> Stream.into(upload_stream) |> Stream.run()
    id = upload_stream.id

    doc = %{
      title: title,
      metadata: metadata,
      body: id
    }

    case Mongo.insert_one(:mongo, "books", doc) do
      {:ok, %Mongo.InsertOneResult{acknowledged: true, inserted_id: doc_id}} ->
        {:ok, stream} = Mongo.GridFs.Download.open_download_stream(bucket, id)

        {:ok,
         %BookBank.Book{
           id: BSON.ObjectId.encode!(doc_id),
           title: title,
           metadata: metadata,
           body: stream
         }}

      {:ok, %Mongo.InsertOneResult{}} ->
        {:error, "Write was not successful"}

      {:error, error} ->
        {:error, error}
    end
  end

  defp with_object_id(id_string, func) do
    case BSON.ObjectId.decode(id_string) do
      {:ok, id} -> func.(id)
      :error -> {:error, :does_not_exist}
    end
  end

  def read_book(id_string) do
    with_object_id(id_string, fn id ->
      case Mongo.find_one(:mongo, "books", %{_id: id}) do
        %{_id: id, title: title, metadata: metadata, body: body_id} ->
          bucket = Mongo.GridFs.Bucket.new(:mongo)
          {:ok, stream} = Mongo.GridFs.Download.open_download_stream(bucket, body_id)

          {:ok,
           %BookBank.Book{
             id: BSON.ObjectId.encode!(id),
             title: title,
             metadata: metadata,
             body: stream
           }}

        %{} ->
          {:error, "Malformed data"}

        nil ->
          {:error, :does_not_exist}
      end
    end)
  end

  def update(set, push, pull, []) do
    {set, push, pull}
  end

  def update(set, push, pull, [head | tail]) do
    case head do
      {:remove, k} ->
        update(set, push, [k | pull], tail)

      {:update, k, v} ->
        update(set, [[k, v] | push], pull, tail)

      {:replace_metadata, m} ->
        update(m, push, pull, tail)
    end
  end

  def update(updates) do
    update(nil, [], [], updates)
  end

  def update_book(id_string, updates) do
    with_object_id(id_string, fn id ->
      {set, push, pull} = update(updates)

      obj = %{
        "$addToSet": %{
          metadata: push
        },
        "$pull": %{
          metadata: pull
        }
      }

      obj =
        case set do
          %{} = m -> Map.put(obj, "$set", %{metadata: m})
          nil -> obj
        end

      case Mongo.update_many(:mongo, "books", %{_id: BSON.ObjectId.decode!(id)}, obj) do
        {:ok, %Mongo.UpdateResult{acknowledged: true}} ->
          :ok

        {:ok, %Mongo.UpdateResult{}} ->
          {:error, "The update was not acknowledged"}

        {:error, error} ->
          {:error, error.message}
      end
    end)
  end

  def delete_book(id_string) do
    with_object_id(id_string, fn id ->
      case Mongo.delete_one(:mongo, "books", %{_id: id}) do
        {:ok, %Mongo.DeleteResult{acknowledged: true, deleted_count: n}} when n > 0 ->
          :ok

        {:ok, %Mongo.DeleteResult{acknowledged: true}} ->
          {:error, :does_not_exist}

        {:ok, %Mongo.DeleteResult{}} ->
          {:error, "The deletion was not acknowledged"}

        {:error, error} ->
          {:error, error.message}
      end
    end)
  end
end
