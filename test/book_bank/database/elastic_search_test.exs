defmodule BookBank.ElasticSearchTest do
  use ExUnit.Case, async: false
  import Mox
  import BookBank.ElasticSearch

  @moduletag :elastic

  setup :verify_on_exit!

  setup do
    :ok = BookBank.ElasticSearch.init()

    on_exit(fn ->
      :ok = delete_book_index()
    end)
  end

  test "Add/retrieve document" do
    book = %BookBank.Book{
      id: "abc",
      title: "Green Eggs and Ham",
      size: 4096,
      metadata: %{"Author" => "Dr. Seuss", "ISBN" => "1234567890"}
    }

    insert_book(book)
    Process.sleep(1000)
    assert {:ok, [^book]} = search("Green Eggs", 1, 0)
  end

  test "Returns typo" do
    book = %BookBank.Book{
      id: "1",
      title: "Green Eggs and Ham",
      size: 4096,
      metadata: %{"Author" => "Dr. Seuss", "ISBN" => "1234567890"}
    }

    insert_book(book)
    Process.sleep(1000)
    assert {:ok, [^book]} = search("Grern Eggs", 1, 0)
  end

  test "Does not return irrelevant document" do
    book = %BookBank.Book{
      id: "1",
      title: "Green Eggs and Ham",
      size: 4096,
      metadata: %{"Author" => "Dr. Seuss", "ISBN" => "1234567890"}
    }

    insert_book(book)
    Process.sleep(1000)
    assert {:ok, []} = search("Foo Bar", 1, 0)
  end

  test "Returns document by author" do
    book = %BookBank.Book{
      id: "1",
      title: "Green Eggs and Ham",
      size: 4096,
      metadata: %{"Author" => "Dr. Seuss", "ISBN" => "1234567890"}
    }

    insert_book(book)
    Process.sleep(1000)
    assert {:ok, [^book]} = search("Dr. Seuss", 1, 0)
  end

  test "Returns multiple documents by author" do
    book1 = %BookBank.Book{
      id: "1",
      title: "Green Eggs and Ham",
      size: 4096,
      metadata: %{"Author" => "Dr. Seuss", "ISBN" => "1234567890"}
    }

    book2 = %BookBank.Book{
      id: "2",
      title: "Cat in the Hat",
      size: 8192,
      metadata: %{"Author" => "Dr. Seuss", "ISBN" => "0987654321"}
    }

    book3 = %BookBank.Book{
      id: "3",
      title: "One Fish Two Fish Red Fish Green Fish",
      size: 2048,
      metadata: %{"Author" => "Dr. Seuss", "ISBN" => "1111111111"}
    }

    insert_book(book1)
    insert_book(book2)
    insert_book(book3)

    Process.sleep(1000)

    assert {:ok, [^book1, ^book2, ^book3]} = search("Seuss", 3, 0)
  end

  test "Returns multiple documents by title" do
    book1 = %BookBank.Book{
      id: "1",
      title: "Green Eggs and Ham",
      size: 4096,
      metadata: %{"Author" => "Dr. Seuss", "ISBN" => "1234567890"}
    }

    book2 = %BookBank.Book{
      id: "2",
      title: "Cat in the Hat",
      size: 8192,
      metadata: %{"Author" => "Dr. Seuss", "ISBN" => "0987654321"}
    }

    book3 = %BookBank.Book{
      id: "3",
      title: "One Fish Two Fish Red Fish Green Fish",
      size: 2048,
      metadata: %{"Author" => "Dr. Seuss", "ISBN" => "1111111111"}
    }

    insert_book(book1)
    insert_book(book2)
    insert_book(book3)

    Process.sleep(1000)

    assert {:ok, [^book1, ^book3]} = search("green", 3, 0)
  end

  test "Returns documents on multiple pages" do
    book1 = %BookBank.Book{
      id: "1",
      title: "Green Eggs and Ham",
      size: 4096,
      metadata: %{"Author" => "Dr. Seuss", "ISBN" => "1234567890"}
    }

    book2 = %BookBank.Book{
      id: "2",
      title: "Cat in the Hat",
      size: 8192,
      metadata: %{"Author" => "Dr. Seuss", "ISBN" => "0987654321"}
    }

    book3 = %BookBank.Book{
      id: "3",
      title: "One Fish Two Fish Red Fish Green Fish",
      size: 2048,
      metadata: %{"Author" => "Dr. Seuss", "ISBN" => "1111111111"}
    }

    insert_book(book1)
    insert_book(book2)
    insert_book(book3)

    Process.sleep(1000)

    assert {:ok, [^book1, ^book2]} = search("Seuss", 2, 0)
    assert {:ok, [^book3]} = search("Seuss", 2, 1)
  end
end
