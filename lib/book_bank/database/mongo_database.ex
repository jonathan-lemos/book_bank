defmodule BookBank.MongoDatabase do
  @behaviour BookBank.DatabaseBehavior
  @search_service Application.get_env(:book_bank, :services)[BookBank.SearchBehavior]
  @thumbnail_service Application.get_env(:book_bank, :services)[BookBank.ThumbnailBehavior]

  alias BookBank.Utils.Mongo, as: Utils

  defp generate_thumbnails(filename) do
    thumb = Briefly.create!()
    cover = Briefly.create!()

    handle_error = fn file ->
      case File.read(file) do
        {:ok, string} -> string
        {:error, _} -> "The output file #{file} no longer exists."
      end
    end

    IO.puts("generating thumbnails")

    case BookBank.Utils.Parallel.invoke([
           fn ->
             @thumbnail_service.create(
               File.stream!(filename, [], 4096),
               File.stream!(cover, [], 4096),
               1000,
               1000
             )
           end,
           fn ->
             @thumbnail_service.create(
               File.stream!(filename, [], 4096),
               File.stream!(thumb, [], 4096),
               300,
               300
             )
           end
         ]) do
      [{:ok, _cover}, {:ok, _thumb}] ->
        IO.puts("generated thumbnails")
        {:ok, File.stream!(cover, [], 4096), File.stream!(thumb, [], 4096)}

      [{:error, _e}, _] ->
        IO.puts("failed")
        {:error, handle_error.(thumb)}

      [_, {:error, _e}] ->
        IO.puts("failed")
        {:error, handle_error.(cover)}
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

    with {:thumb, {:ok, cover, thumb}} <- {:thumb, generate_thumbnails(pdf_file)},
         {:insert, {:ok, id}} <-
           {:insert,
            Utils.insert_with_files("books", doc, [
              {["cover"], cover, "#{title}.jpg", "covers"},
              {["thumbnail"], thumb, "#{title}.jpg", "thumbnails"},
              {["body"], File.stream!(pdf_file, [], 4096), "#{title}.pdf", "files"}
            ])},
         book <- %BookBank.Book{id: id, title: title, metadata: metadata, size: size},
         {:search, :ok, _id, book} <-
           {:search,
            @search_service.insert_book(%BookBank.Book{
              id: id,
              title: title,
              metadata: metadata,
              size: size
            }), id, book} do
      {:ok, book}
    else
      {:thumb, {:error, e}} ->
        {:error, "Failed to generate thumbnails: #{e}"}

      {:insert, {:error, e}} ->
        {:error, "Failed to insert document and/or files: #{e}"}

      {:search, {:error, e}, id, _book} ->
        case Utils.delete("books", %{_id: id}) do
          :ok ->
            {:error, "Failed to insert document into Elasticsearch: #{e}"}

          {:error, msg} ->
            {:inconsistent,
             "Failed to insert document into Elasticsearch: #{e}. Also failed to remove document from mongo: #{
               msg
             }."}
        end
    end
  end

  defp doc_to_book(%{"_id" => id, "metadata" => metadata, "title" => title, "size" => size}) do
    case metadata |> Utils.kvplist_to_kvpmap() do
      {:ok, map} ->
        {:ok, %BookBank.Book{id: id, metadata: map, title: title, size: size}}

      {:error, _} ->
        {:error, "The 'metadata' field is malformed: #{Kernel.inspect(metadata)}."}
    end
  end

  defp doc_to_book(doc) do
    {:error, "#{Kernel.inspect(doc)} cannot be converted into a book"}
  end

  @impl true
  def get_book_metadata(id) do
    case Utils.find("books", %{_id: id}) do
      {:ok, doc} ->
        doc_to_book(doc)

      {:error, e} ->
        {:error, e}
    end
  end

  defp get_book_file_from_path(id, path) do
    case Utils.find_file("books", %{_id: id}, path) do
      {:ok, stream, doc} ->
        case doc_to_book(doc) do
          {:ok, book} -> {:ok, stream, book}
          {:error, e} -> {:error, e}
        end
    end
  end

  @impl true
  def get_book_cover(id) do
    get_book_file_from_path(id, ["cover"])
  end

  @impl true
  def get_book_file(id) do
    get_book_file_from_path(id, ["body"])
  end

  @impl true
  def get_book_thumb(id) do
    get_book_file_from_path(id, ["thumbnail"])
  end

  defp update_metadata(metadata, add, remove, set) when map_size(set) === 0 do
    remove_set = remove |> MapSet.new()

    metadata
    |> Enum.filter(fn %{"key" => k} -> not MapSet.member?(remove_set, k) end)
    |> Utils.kvplist_to_kvpmap!()
    |> Map.merge(add)
    |> Utils.kvpmap_to_kvplist!()
  end

  defp update_metadata(_metadata, _add, _remove, set) do
    set |> Utils.kvpmap_to_kvplist!()
  end

  @impl true
  def update_book(id_string, updates) do
    with {:ok,
          %{"_id" => id, "title" => title, "metadata" => metadata, "size" => size} = document}
         when is_binary(title) and size >= 0 <-
           Utils.find("books", %{_id: id_string}),
         {document, true} <- {document, BookBank.Utils.Mongo.is_kvplist(metadata)} do
      metadata =
        update_metadata(
          metadata,
          updates[:add_metadata] || %{},
          updates[:remove_metadata] || [],
          updates[:set_metadata] || %{}
        )

      title = updates[:set_title] || title

      new_document = document |> Map.merge(%{"title" => title, "metadata" => metadata})

      with {:replace, :ok} <- {:replace, Utils.replace("books", id, new_document)},
           {:search, :ok} <-
             {:search,
              @search_service.update_book(%BookBank.Book{
                id: id,
                metadata: metadata |> Utils.kvplist_to_kvpmap!(),
                title: title,
                size: size
              })} do
        :ok
      else
        {:replace, {:error, e}} ->
          {:error, "Failed to update document in mongo: #{e}."}

        {:search, {:error, e}} ->
          case Utils.replace("books", id, document) do
            :ok ->
              {:error, "Failed to update document in Elasticsearch: #{e}"}

            {:error, msg} ->
              {:inconsistent,
               "Failed to update document in Elasticsearch: #{e}. Additionally failed to revert update in mongo: #{
                 msg
               }."}
          end
      end
    else
      {document, false} ->
        {:error,
         "The 'metadata' field of the database entry #{Kernel.inspect(document)} is malformed."}

      {:ok, document} ->
        {:error, "The database entry #{Kernel.inspect(document)} is malformed."}

      {:error, e} ->
        {:error, e}
    end
  end

  @impl true
  def delete_book(id) do
    with {:ok, doc} <- Utils.delete("books", %{_id: id}) do
      case @search_service.delete_book(id) do
        :ok ->
          :ok

        {:error, e} ->
          case Utils.insert(doc) do
            {:ok, _id} ->
              {:error, "Failed to delete document from Elasticsearch: #{e}."}

            {:error, msg} ->
              {:inconsistent,
               "Failed to delete document from Elasticsearch: #{e}. Additionally failed to revert deletion in mongo: #{
                 msg
               }."}
          end
      end
    else
      {:error, e} -> {:error, "Failed to delete document from mongo: #{e}."}
    end
  end
end
