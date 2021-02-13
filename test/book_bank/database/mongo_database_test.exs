defmodule BookBank.MongoDatabaseTest do
  use ExUnit.Case, async: false
  import Mox
  import BookBank.MongoDatabase

  @moduletag :mongo

  setup :verify_on_exit!

  setup do
    {:ok, _pid} =
      Mongo.start_link(
        name: :mongo,
        database: "test",
        url: Application.get_env(:book_bank, BookBank.MongoDatabase)[:url]
      )

    BookBank.Utils.Mongo.init()

    on_exit(fn ->
      {:ok, _pid} =
        Mongo.start_link(
          name: :mongo,
          database: "test",
          url: Application.get_env(:book_bank, BookBank.MongoDatabase)[:url]
        )

      Mongo.drop_database(:mongo, "test")
    end)
  end

  def assert_create_book(title, content, metadata \\ %{}) do
    expect(BookBank.MockSearch, :insert_book, fn %BookBank.Book{title: ^title, metadata: ^metadata} -> :ok end)
    expect(BookBank.MockThumbnail, :create, 2, fn stream, _, _ -> {:ok, stream} end)

    len = String.length(content)
    content_stream = [content] |> Stream.map(& &1)
    assert {:ok, %BookBank.Book{title: ^title, size: ^len, metadata: ^metadata} = book} =
             create_book(title, content_stream, metadata)

    book
  end

  def assert_get_book_metadata(id, content, metadata) do
    len = String.length(content)
    assert {:ok, %BookBank.Book{id: ^id, size: ^len, metadata: ^metadata} = book} =
             get_book_metadata(id)

    book
  end

  test "Can retrieve created book" do
    %BookBank.Book{id: id} = assert_create_book("Green Eggs and Ham", "sam", %{"Author" => "Dr. Seuss"})
    assert_get_book_metadata(id, "sam", %{"Author" => "Dr. Seuss"})
  end
end
