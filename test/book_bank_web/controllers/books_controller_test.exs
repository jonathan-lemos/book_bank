defmodule BookBankWeb.BooksControllerTest do
  use BookBankWeb.ConnCase, async: true
  import Mox
  import Test.Utils

  setup :verify_on_exit!

  def expect_stream(list, db_func, keywords \\ []) do
    content_stream = list |> Stream.map(& &1)
    Enum.each(list, &expect(BookBankWeb.Utils.MockChunk, :send_chunk, fn conn, ^&1 -> conn end))

    id = keywords[:id] || "1"

    expect(BookBank.MockDatabase, db_func, fn ^id ->
      {:ok, content_stream,
       %BookBank.Book{
         id: id,
         size: Enum.reduce(list, 0, fn chunk, acc -> acc + bit_size(chunk) end),
         title: keywords[:title] || "Test Title",
         metadata: keywords[:metadata] || %{}
       }}
    end)
  end

  test "GET /api/books/cover/1 success", %{conn: conn} do
    expect_stream(["abc", "def", "ghi"], :get_book_cover)

    conn =
      with_token(conn, "user")
      |> get("/api/books/cover/1")

    assert conn.status === 200
    assert {"content-disposition", "inline"} in conn.resp_headers
  end

  test "GET /api/books/metadata/1 success", %{conn: conn} do
    expect(BookBank.MockDatabase, :get_book_metadata, fn "1" ->
      {:ok,
       %BookBank.Book{
         id: "1",
         title: "Green Eggs and Cum",
         size: 12345,
         metadata: [
           %{"key" => "Author", "value" => "Mr. Seuss"},
           %{"key" => "ISBN-10", "value" => "1234567890"}
         ]
       }}
    end)

    conn =
      with_token(conn, "user")
      |> get("/api/books/metadata/1")

    assert %{
             "title" => "Green Eggs and Cum",
             "size" => 12345,
             "metadata" => [
               %{"key" => "Author", "value" => "Mr. Seuss"},
               %{"key" => "ISBN-10", "value" => "1234567890"}
             ]
           } = conn |> Phoenix.ConnTest.json_response(:ok)
  end

  test "GET /api/books/download/1 success", %{conn: conn} do
    expect_stream(["abc", "def", "ghi"], :get_book_file, title: "foo bar")

    conn =
      with_token(conn, "user")
      |> get("/api/books/download/1")

    assert conn.status === 200
    assert {"content-disposition", "attachment; filename=\"foo%20bar.pdf\""} in conn.resp_headers
  end

  test "GET /api/books/view/1 success", %{conn: conn} do
    expect_stream(["abc", "def", "ghi"], :get_book_file)

    conn =
      with_token(conn, "user")
      |> get("/api/books/view/1")

    assert conn.status === 200
    assert {"content-disposition", "inline"} in conn.resp_headers
  end

  test "GET /api/books/thumbnail/1 success", %{conn: conn} do
    expect_stream(["abc", "def", "ghi"], :get_book_thumb)

    conn =
      with_token(conn, "user")
      |> get("/api/books/thumbnail/1")

    assert conn.status === 200
    assert {"content-disposition", "inline"} in conn.resp_headers
  end

  test "POST /api/books success", %{conn: conn} do
    expect(BookBank.MockDatabase, :create_book, fn "Test Title", stream, %{} ->
      contents = Enum.join(stream)
      assert contents == "abcde"
      {:ok, %BookBank.Book{id: "1", size: 5, title: "Test Title", metadata: %{}}}
    end)

    conn =
      with_token(conn, "user", ["librarian"])
      |> multipart_formdata_req(&post/3, "/api/books", %{
        "title" => "Test Title",
        "book" => {"abcde", filename: "test.pdf", content_type: "application/pdf"}
      })

    assert %{"id" => "1"} = conn |> Phoenix.ConnTest.json_response(:created)
  end

  test "PUT /api/books/metadata/1 success", %{conn: conn} do
    expect(BookBank.MockDatabase, :update_book, fn "1", list ->
      assert list[:set_title] === "New Title"

      assert list[:replace_metadata] === [
               %{"key" => "Author", "value" => "Dr. Seuss"},
               %{"key" => "ISBN-13", "value" => "1234567890-123"}
             ]

      :ok
    end)

    conn =
      with_token(conn, "user", ["librarian"])
      |> json_req(&put/3, "/api/books/metadata/1", %{
        "title" => "New Title",
        "metadata" => [
          %{"key" => "Author", "value" => "Dr. Seuss"},
          %{"key" => "ISBN-13", "value" => "1234567890-123"}
        ]
      })

    assert %{} = conn |> Phoenix.ConnTest.json_response(:ok)
  end

  test "PATCH /api/books/metadata/1 success", %{conn: conn} do
    expect(BookBank.MockDatabase, :update_book, fn "1", list ->
      groups = list |> Enum.group_by(fn {k, v} -> k end, fn {k, v} -> v end)
      assert list[:set_title] === "New Title"

      assert list[:replace_metadata] === [
               %{"key" => "Author", "value" => "Dr. Seuss"},
               %{"key" => "ISBN-13", "value" => "1234567890-123"}
             ]

      :ok
    end)

    conn =
      with_token(conn, "user", ["librarian"])
      |> json_req(&patch/3, "/api/books/metadata/1", %{
        "title" => "New Title",
        "add" => %{
          "Rating" => "4.77",
          "Test" => "Value"
        },
        "remove" => []
      })
  end
end
