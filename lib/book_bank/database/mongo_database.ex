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

  def read_book(id) do
    case Mongo.find_one(:mongo, "books", %{_id: BSON.ObjectId.decode!(id)}) do
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
  end
end
