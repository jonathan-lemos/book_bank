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

  test "POST /api/books", %{conn: conn} do
    expect(BookBank.MockDatabase, :create_book, fn "Test Title", stream, %{} ->
      contents = Enum.join(stream)
      assert contents == "abcde"
      {:ok, %BookBank.Book{id: "1", title: "Test Title", metadata: %{}}}
    end)

    conn =
      with_token(conn, "user", ["librarian"])
      |> multipart_formdata_req(&post/3, "/api/books", %{
        "title" => "Test Title",
        "book" => {"abcde", filename: "test.pdf", content_type: "application/pdf"}
      })

    assert conn.status === 201
  end
end
