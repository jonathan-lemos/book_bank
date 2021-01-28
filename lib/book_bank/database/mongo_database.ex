defmodule BookBank.MongoDatabase do
  @behaviour BookBank.DatabaseBehavior

  defp create_file(filename, file_stream, bucket_name \\ "fs") do
    bucket = Mongo.GridFs.Bucket.new(:mongo, name: bucket_name)
    upload_stream = Mongo.GridFs.Upload.open_upload_stream(bucket, filename)

    file_stream |> Stream.into(upload_stream) |> Stream.run()
    id = upload_stream.id |> BSON.ObjectId.encode!()
    {:ok, id}
  end

  defp download_file(id, bucket_name \\ "fs") do
    bucket = Mongo.GridFs.Bucket.new(:mongo, name: bucket_name)

    case Mongo.GridFs.Download.open_download_stream(bucket, id) do
      {:ok, stream} -> {:ok, stream}
      {:error, :not_found} -> {:error, :does_not_exist}
      {:error, _} -> {:error, "Failed to fetch the document."}
    end
  end

  defp delete_file(id, bucket_name \\ "fs") do
    bucket = Mongo.GridFs.Bucket.new(:mongo, name: bucket_name)

    case Mongo.GridFs.Bucket.delete(bucket, id) do
      {:ok, %Mongo.DeleteResult{acknowledged: true, deleted_count: n}} when n > 0 ->
        :ok

      {:ok, %Mongo.DeleteResult{acknowledged: true, deleted_count: 0}} ->
        {:error, :does_not_exist}

      {:ok, %Mongo.DeleteResult{acknowledged: false}} ->
        {:error, "The delete was not acknowledged."}
    end
  end

  def create_book(title, body, metadata) do
    {:ok, id} = create_file("#{title}.pdf", body)

    doc = %{
      title: title,
      metadata: metadata,
      body: id,
      cover: nil,
      thumb: nil
    }

    case Mongo.insert_one(:mongo, "books", doc) do
      {:ok, %Mongo.InsertOneResult{acknowledged: true, inserted_id: doc_id}} ->
        Task.start(fn -> generate_thumbnails(id) end)

        {:ok,
         %BookBank.Book{
           id: BSON.ObjectId.encode!(doc_id),
           title: title,
           metadata: metadata
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

  defp get_document(id_string) do
    with_object_id(id_string, fn id ->
      case Mongo.find_one(:mongo, "books", %{_id: id}) do
        %{
          "_id" => id,
          "title" => title,
          "metadata" => metadata
        } = doc
        when is_binary(id) and is_binary(title) and is_map(metadata) ->
          {:ok, doc}

        %{} ->
          Mongo.delete_many!(:mongo, "books", %{_id: id})
          {:error, :does_not_exist}

        _ ->
          {:error, :does_not_exist}
      end
    end)
  end

  defp doc_to_book(%{"_id" => id, "title" => title, "metadata" => metadata}) do
    %BookBank.Book{id: id, title: title, metadata: metadata}
  end

  def get_book_metadata(id_string) do
    case get_document(id_string) do
      {:ok, doc} ->
        {:ok, doc_to_book(doc)}

      e ->
        e
    end
  end

  def get_book_cover(id_string) do
    with {:ok, %{"cover" => cover_id} = document} <- get_document(id_string) do
      case download_file(cover_id) do
        {:ok, stream} -> {:ok, stream, doc_to_book(document)}
        {:error, _} = e -> e
      end
    else
      {:error, _} = e -> e
      {:ok, %{}} -> {:error, :does_not_exist}
    end
  end

  def get_book_file(id_string) do
    with {:ok, %{"body" => body_id} = document} <- get_document(id_string) do
      case download_file(body_id) do
        {:ok, stream} -> {:ok, stream, doc_to_book(document)}
        {:error, _} = e -> e
      end
    else
      {:error, _} = e -> e
      {:ok, %{}} -> {:error, :does_not_exist}
    end
  end

  def get_book_thumb(id_string) do
    with {:ok, %{"thumb" => thumb_id} = document} <- get_document(id_string) do
      case download_file(thumb_id) do
        {:ok, stream} -> {:ok, stream, doc_to_book(document)}
        {:error, _} = e -> e
      end
    else
      {:error, _} = e -> e
      {:ok, %{}} -> {:error, :does_not_exist}
    end
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
        update(%{set | metadata: m}, push, pull, tail)

      {:set_title, title} ->
        update(%{set | title: title}, push, pull, tail)
    end
  end

  def update(updates) do
    update(%{}, [], [], updates)
  end

  def update_book(id_string, updates) do
    with_object_id(id_string, fn id ->
      {set, push, pull} = update(updates)

      obj = %{
        "$set": set,
        "$addToSet": %{
          metadata: push
        },
        "$pull": %{
          metadata: pull
        }
      }

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
          BookBank.Utils.Parallel.invoke(
            ["fs", "thumbnails", "covers"]
            |> Enum.map(fn bucket -> fn -> delete_file(id, bucket) end end)
          )

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

  defp pdf_thumbnail(pdf_path, out_path) do
    case System.cmd(
           "convert",
           ["-density", "300", "-resize", "300x300", "#{pdf_path}[0]", "#{out_path}"],
           stderr_to_stdout: true
         ) do
      {_, 0} -> :ok
      {reason, _} -> {:error, reason}
    end
  end

  defp pdf_cover(pdf_path, out_path) do
    case System.cmd(
           "convert",
           ["-density", "300", "-resize", "1000x1000", "#{pdf_path}[0]", "#{out_path}"],
           stderr_to_stdout: true
         ) do
      {_, 0} -> :ok
      {reason, _} -> {:error, reason}
    end
  end

  def generate_thumbnails(id_string) do
    with_object_id(id_string, fn id ->
      tmpdir = System.tmp_dir!()
      thumb_fn = "thumb_#{id}.jpg"
      cover_fn = "cover_#{id}.jpg"
      pdf_path = Path.join(tmpdir, "#{id}.pdf")
      thumb_path = Path.join(tmpdir, thumb_fn)
      cover_path = Path.join(tmpdir, cover_fn)

      ret =
        with {:ok, stream, _book} <-
               get_book_file(id_string),
             :ok <- stream |> Stream.into(File.stream!(pdf_path)) |> Stream.run(),
             [:ok, :ok] <-
               BookBank.Utils.Parallel.invoke([
                 fn -> pdf_thumbnail(pdf_path, thumb_path) end,
                 fn -> pdf_cover(pdf_path, cover_path) end
               ]),
             {:ok, thumb_id} <- create_file(thumb_fn, File.stream!(thumb_path), "thumb"),
             {:ok, cover_id} <- create_file(cover_fn, File.stream!(cover_path), "cover") do
          result =
            case Mongo.update_one(:mongo, "books", %{"_id" => id}, %{
                   "$set" => %{
                     "thumb" => thumb_id |> BSON.ObjectId.decode!(),
                     "cover" => cover_id |> BSON.ObjectId.decode!()
                   }
                 }) do
              {:ok, %Mongo.UpdateResult{acknowledged: true}} ->
                :ok

              {:ok, %Mongo.UpdateResult{}} ->
                {:error, "The update was not acknowledged"}

              {:error, error} ->
                {:error, error.message}
            end

          case result do
            :ok ->
              :ok

            {:error, _} = e ->
              BookBank.Utils.Parallel.invoke([
                fn -> delete_file(thumb_id, "thumb") end,
                fn -> delete_file(cover_id, "cover") end
              ])

              e
          end
        else
          [{:error, e1}, {:error, e2}] -> {:error, [{:pdf, e1}, {:thumb, e2}]}
          [{:error, e1}, _] -> {:error, :pdf, e1}
          [_, {:error, e2}] -> {:error, :thumb, e2}
          {:error, e} when is_binary(e) -> {:error, e}
          {:error, :does_not_exist} -> {:error, :does_not_exist}
          {:error, a} when is_atom(a) -> {:error, :file.format_error(a)}
        end

      Enum.each([pdf_path, thumb_path, cover_path], &File.rm/1)

      ret
    end)
  end
end
