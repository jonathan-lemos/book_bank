defmodule BookBank.MongoDatabase do
  @behaviour BookBank.DatabaseBehavior
  @search_service Application.get_env(:book_bank, :services)[BookBank.SearchBehavior]
  @thumbnail_service Application.get_env(:book_bank, :services)[BookBank.ThumbnailBehavior]

  defp create_file(filename, file_stream, bucket_name \\ "fs") do
    bucket = Mongo.GridFs.Bucket.new(:mongo, name: bucket_name)
    upload_stream = Mongo.GridFs.Upload.open_upload_stream(bucket, filename)

    size =
      file_stream
      |> Stream.into(upload_stream)
      |> Enum.reduce(0, fn chunk, acc -> acc + byte_size(chunk) end)

    id = upload_stream.id |> BSON.ObjectId.encode!()
    {:ok, id, size}
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

  defp upload_pdf_and_thumbnails(id, filename) do
    case BookBank.Utils.Parallel.invoke([
           fn -> create_file("#{id}.pdf", File.stream!(filename)) end,
           fn ->
             with {:ok, cover} <- @thumbnail_service.create(File.stream!(filename), 1000, 1000) do
               create_file("#{id}.jpg", cover, "covers")
             else
               e -> e
             end
           end,
           fn ->
             with {:ok, thumb} <- @thumbnail_service.create(File.stream!(filename), 300, 300) do
               create_file("#{id}.jpg", thumb, "thumbnails")
             else
               e -> e
             end
           end
         ]) do
      [{:ok, id, size}, {:ok, _id_cover, _size_cover}, {:ok, _id_thumb, _size_thumb}] ->
        {:ok, id, size}

      [_pdf_res, _cover_res, _thumb_res] = results ->
        {:error,
         results
         |> Enum.zip(["Error uploading PDF: ", "Error uploading book cover: ", "Error uploading book thumbnail: "])
         |> Enum.filter(&match?({{:error, _}, _}, &1))
         |> Enum.map(fn {{:error, e}, prefix} -> prefix <> e end)
         |> Enum.join(". ")}
    end
  end

  @impl true
  def create_book(title, body, metadata) do
    pdf_file = Briefly.create!()
    body |> Stream.into(File.stream!(pdf_file)) |> Stream.run()
    size = File.stat!(pdf_file).size

    doc = %{
      title: title,
      metadata: metadata |> BookBank.Utils.Mongo.kvpmap_to_kvplist!(),
      size: size,
      body: nil,
      cover: nil,
      thumb: nil
    }

    case Mongo.insert_one(:mongo, "books", doc) do
      {:ok, %Mongo.InsertOneResult{acknowledged: true, inserted_id: doc_id}} ->
        book = %BookBank.Book{
          id: BSON.ObjectId.encode!(doc_id),
          title: title,
          size: size,
          metadata: metadata
        }

        case @search_service.insert_book(book) do
          :ok ->
            {:ok, book}

          {:error, reason} ->
            Mongo.delete_one(:mongo, "books", %{_id: doc_id})
            {:error, reason}
        end

        Task.start(fn -> generate_thumbnails(id) end)

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
        when is_binary(id) and is_binary(title) and is_list(metadata) ->
          {:ok, doc}

        %{} ->
          Mongo.delete_many!(:mongo, "books", %{_id: id})
          {:error, :does_not_exist}

        _ ->
          {:error, :does_not_exist}
      end
    end)
  end

  defp doc_to_book(%{"_id" => id, "size" => size, "title" => title, "metadata" => metadata}) do
    %BookBank.Book{id: id, size: size, title: title, metadata: metadata}
  end

  @impl true
  def get_book_metadata(id_string) do
    case get_document(id_string) do
      {:ok, doc} ->
        {:ok, doc_to_book(doc)}

      e ->
        e
    end
  end

  @impl true
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

  @impl true
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

  @impl true
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

  @impl true
  def update_book(id_string, updates) do
    with {:ok, %{"_id" => id, "title" => title, "metadata" => metadata}} = document
         when is_binary(title) and is_list(metadata) <-
           get_document(id_string) do
      if not BookBank.Utils.Mongo.is_kvplist(metadata) do
        raise ArgumentError, message: "The database entry for #{id_string} is malformed."
      end

      remove = (updates[:remove_roles] || []) |> MapSet.new()

      metadata =
        metadata
        |> Enum.filter(fn %{"key" => k} -> remove |> MapSet.member?(k) |> Kernel.not() end)

      add = updates[:update_roles] || %{}

      metadata =
        metadata
        |> BookBank.Utils.Mongo.kvplist_to_kvpmap!()
        |> Map.merge(add)
        |> BookBank.Utils.Mongo.kvpmap_to_kvplist!()

      title = updates[:update_title] || title

      new_document = document |> Map.merge(%{"title" => title, "metadata" => metadata})

      case Mongo.replace_one(:mongo, "books", %{_id: id}, new_document) do
        {:ok, %Mongo.UpdateResult{acknowledged: true, matched_count: n}} when n > 0 ->
          new_book = doc_to_book(document)

          case @search_service.update_book(new_book) do
            :ok ->
              :ok

            {:error, e} ->
              Mongo.replace_one(:mongo, "books", %{_id: id}, document)
              {:error, e}
          end

          :ok

        {:ok, %Mongo.UpdateResult{}} ->
          {:error, "The update was not acknowledged"}

        {:error, error} ->
          {:error, error.message}
      end
    end
  end

  @impl true
  def delete_book(id_string) do
    with_object_id(id_string, fn id ->
      case Mongo.delete_one(:mongo, "books", %{_id: id}) do
        {:ok, %Mongo.DeleteResult{acknowledged: true, deleted_count: n}} when n > 0 ->
          BookBank.Utils.Parallel.invoke(
            ["fs", "thumbnails", "covers"]
            |> Enum.map(fn bucket -> fn -> delete_file(id, bucket) end end)
          )

          @search_service.delete_book(id_string)

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
      thumb_fn = Briefly.create!()
      cover_fn = Briefly.create!()
      pdf_path = Briefly.create!()

      with {:ok, stream, _book} <-
             get_book_file(id_string),
           :ok <- stream |> Stream.into(File.stream!(pdf_path)) |> Stream.run(),
           [{:ok, thumbnail}, {:ok, cover}] <-
             BookBank.Utils.Parallel.invoke([
               fn -> @thumbnail_service.create(File.stream!(pdf_path), 300, 300) end,
               fn -> @thumbnail_service.create(File.stream!(pdf_path), 1000, 1000) end
             ]),
           {:ok, thumb_id, _size} <- create_file(thumb_fn, File.stream!(thumb_fn), "thumb"),
           {:ok, cover_id, _size} <- create_file(cover_fn, File.stream!(cover_fn), "cover") do
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
    end)
  end
end
