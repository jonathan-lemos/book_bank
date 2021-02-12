defmodule BookBank.MongoDatabase do
  @behaviour BookBank.DatabaseBehavior
  @search_service Application.get_env(:book_bank, :services)[BookBank.SearchBehavior]
  @thumbnail_service Application.get_env(:book_bank, :services)[BookBank.ThumbnailBehavior]

  alias BookBank.Utils.Mongo, as: Utils

  defp generate_thumbnails(filename) do
    case BookBank.Utils.Parallel.invoke([
           fn ->
             @thumbnail_service.create(File.stream!(filename), 1000, 1000)
           end,
           fn ->
             @thumbnail_service.create(File.stream!(filename), 300, 300)
           end
         ]) do
      [{:ok, cover}, {:ok, thumb}] -> {:ok, cover, thumb}
      [{:error, e}, _] -> {:error, e}
      [_, {:error, e}] -> {:error, e}
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
      size: size
    }

    with {:ok, cover, thumb} <- generate_thumbnails(pdf_file) do
      case Utils.insert_with_files("books", doc, [
             {["cover"], cover, "#{title}.jpg", "covers"},
             {["thumbnail"], thumb, "#{title}.jpg", "thumbnails"},
             {["body"], File.stream!(pdf_file, [], 4096), "#{title}.pdf", "files"}
           ]) do
        {:ok, id} -> {:ok, %BookBank.Book{id: id, title: title, metadata: metadata, size: size}}
        {:error, e} -> {:error, e}
      end
    else
      {:error, e} -> {:error, "Failed to generate thumbnails: #{e}"}
    end
  end

  @impl true
  def get_book_metadata(id) do
    case Utils.find_one("books", %{_id: id}) do
      {:ok, %{"_id" => id, "metadata" => metadata, "title" => title, "size" => size}} ->
        {:ok, %BookBank.Book{id: id, metadata: metadata, title: title, size: size}}

      {:error, e} ->
        {:error, e}
    end
  end

  @impl true
  def get_book_cover(id) do
    case Utils.find_one("books", %{_id: id}) do

    end
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
