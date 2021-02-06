defmodule BookBankWeb.SearchControllerTest do
  use BookBankWeb.ConnCase, async: true
  import Mox
  import Test.Utils

  setup :verify_on_exit!

  test "/api/search/query/test success", %{conn: conn} do
    res = [
        %{
          "id" => "1",
          "title" => "Green Eggs and Ham",
          "metadata" => %{"main character" => "sam i am", "author" => "doctor seuss"}
        },
        %{
          "id" => "2",
          "title" => "Cat in the Hat",
          "metadata" => %{"main character" => "cat", "author" => "dr seuss"}
        }
      ]

    expect(BookBank.MockSearch, :search, fn "test", _count, _page ->
      {:ok, res}
    end)

    conn =
      with_token(conn, "user")
      |> get("/api/search/query/test")

    assert %{"results" => ^res} = conn |> json_response(:ok)
  end
end
