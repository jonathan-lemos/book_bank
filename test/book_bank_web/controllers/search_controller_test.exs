defmodule BookBankWeb.SearchControllerTest do
  use BookBankWeb.ConnCase, async: true
  import Mox
  import Test.Utils

  setup :verify_on_exit!

  test "/api/search/query/test success", %{conn: conn} do
    search_response = [
      %BookBank.Book{
        id: "1",
        title: "Green Eggs and Ham",
        size: 69,
        metadata: %{"main character" => "sam i am", "author" => "doctor seuss"}
      },
      %BookBank.Book{
        id: "2",
        title: "Cat in the Hat",
        size: 999,
        metadata: %{"main character" => "cat", "author" => "dr seuss"}
      }
    ]

    api_response =
      search_response
      |> Stream.map(&Map.from_struct/1)
      |> Enum.map(fn map ->
        map
        |> Stream.map(fn {k, v} -> {Atom.to_string(k), v} end)
        |> Map.new()
      end)

    expect(BookBank.MockSearch, :search, fn "test", _count, _page ->
      {:ok, search_response}
    end)

    conn =
      with_token(conn, "user")
      |> get("/api/search/query/test")

    assert %{"results" => ^api_response} = conn |> json_response(:ok)
  end

  test "/api/search/query/test?count=2&page=3 success", %{conn: conn} do
    search_response = [
      %BookBank.Book{
        id: "1",
        title: "Green Eggs and Ham",
        size: 69,
        metadata: %{"main character" => "sam i am", "author" => "doctor seuss"}
      },
      %BookBank.Book{
        id: "2",
        title: "Cat in the Hat",
        size: 999,
        metadata: %{"main character" => "cat", "author" => "dr seuss"}
      }
    ]

    api_response =
      search_response
      |> Stream.map(&Map.from_struct/1)
      |> Enum.map(fn map ->
        map
        |> Stream.map(fn {k, v} -> {Atom.to_string(k), v} end)
        |> Map.new()
      end)

    expect(BookBank.MockSearch, :search, fn "test", 2, 3 ->
      {:ok, search_response}
    end)

    conn =
      with_token(conn, "user")
      |> get("/api/search/query/test?count=2&page=3")

    assert %{"results" => ^api_response} = conn |> json_response(:ok)
  end
end
