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

  def assert_create_book(title, content, metadata \\ %{}, opts \\ []) do
    expect(BookBank.MockSearch, :insert_book, fn %BookBank.Book{
                                                   title: ^title,
                                                   metadata: ^metadata
                                                 } ->
      :ok
    end)

    expect(BookBank.MockThumbnail, :create, 2, fn
      stream, 300, 300 -> {:ok, (opts[:thumbnail] || stream) |> Stream.map(& &1)}
      stream, 1000, 1000 -> {:ok, (opts[:cover] || stream) |> Stream.map(& &1)}
    end)

    len = String.length(content)
    content_stream = [content] |> Stream.map(& &1)

    assert {:ok, %BookBank.Book{title: ^title, size: ^len, metadata: ^metadata} = book} =
             create_book(title, content_stream, metadata)

    book
  end

  def assert_get_book_metadata(id, title, metadata, content) do
    len = String.length(content)

    assert {:ok, %BookBank.Book{id: ^id, size: ^len, metadata: ^metadata, title: ^title} = book} =
             get_book_metadata(id)

    book
  end

  test "Can retrieve created book" do
    %BookBank.Book{id: id} =
      assert_create_book("Green Eggs and Ham", "sam", %{"Author" => "Dr. Seuss"})

    assert_get_book_metadata(id, "Green Eggs and Ham", %{"Author" => "Dr. Seuss"}, "sam")
  end

  test "Can update book" do
    %BookBank.Book{id: id} =
      assert_create_book("Green Eggs and Ham", "sam", %{
        "ISBN-13" => "13",
        "Author" => "Dr. Seuss",
        "Key" => "Value"
      })

    expect(
      BookBank.MockSearch,
      :update_book,
      fn %BookBank.Book{
           title: "Cat in the Hat",
           metadata: %{
             "ISBN" => "69",
             "Author" => "Doctor Seuss"
           }
         } ->
        :ok
      end
    )

    assert :ok =
             update_book(id,
               remove_metadata: ["Author", "ISBN-13"],
               add_metadata: %{
                 "ISBN" => "69",
                 "Author" => "Doctor Seuss"
               },
               set_title: "Cat in the Hat"
             )

    assert_get_book_metadata(
      id,
      "Cat in the Hat",
      %{
        "ISBN" => "69",
        "Author" => "Doctor Seuss",
        "Key" => "Value"
      },
      "sam"
    )
  end

  test "Can set book metadata" do
    %BookBank.Book{id: id} =
      assert_create_book("Green Eggs and Ham", "sam", %{
        "ISBN-13" => "13",
        "Author" => "Dr. Seuss",
        "Key" => "Value"
      })

    expect(
      BookBank.MockSearch,
      :update_book,
      fn %BookBank.Book{
           title: "Green Eggs and Ham",
           metadata: %{
             "New" => "Metadata",
             "Test" => "Test"
           }
         } ->
        :ok
      end
    )

    assert :ok =
             update_book(id,
               remove_metadata: ["Author", "ISBN-13"],
               add_metadata: %{
                 "ISBN" => "69",
                 "Author" => "Doctor Seuss"
               },
               set_metadata: %{
                 "New" => "Metadata",
                 "Test" => "Test"
               }
             )

    assert_get_book_metadata(
      id,
      "Green Eggs and Ham",
      %{
        "New" => "Metadata",
        "Test" => "Test"
      },
      "sam"
    )
  end

  defp download_test(function, atom) do
    %BookBank.Book{id: id} =
      assert_create_book(
        "Green Eggs and Ham",
        "sam",
        %{
          "ISBN-13" => "13",
          "Author" => "Dr. Seuss",
          "Key" => "Value"
        },
        [{atom, ["sam", "i", "am"]}]
      )

    assert {:ok, stream,
            %BookBank.Book{
              title: "Green Eggs and Ham",
              metadata: %{
                "ISBN-13" => "13",
                "Author" => "Dr. Seuss",
                "Key" => "Value"
              },
              size: 3
            }} = function.(id)

    assert "samiam" = stream |> Enum.join()
  end

  test "Can get book cover" do
    download_test(&get_book_cover/1, :cover)
  end

  test "Can get book body" do
    %BookBank.Book{id: id} = book =
      assert_create_book("Green Eggs and Ham", "sam", %{"Author" => "Dr. Seuss"})

      assert {:ok, stream, ^book} = get_book_file(id)

      assert "sam" = stream |> Enum.join()
  end

  test "Can get book thumbnail" do
    download_test(&get_book_thumb/1, :thumbnail)
  end

  test "Can delete book" do
    %BookBank.Book{id: id} =
      assert_create_book("Green Eggs and Ham", "sam", %{"Author" => "Dr. Seuss"})

    expect(BookBank.MockSearch, :delete_book, fn ^id -> :ok end)

    assert :ok = delete_book(id)
  end
end
