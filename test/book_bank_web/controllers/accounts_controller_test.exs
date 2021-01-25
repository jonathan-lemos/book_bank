defmodule BookBankWeb.AccountsControllerTest do
  use BookBankWeb.ConnCase, async: true
  import Mox
  import Test.Utils

  setup :verify_on_exit!

  test "POST /api/accounts/login success", %{conn: conn} do
    expect(BookBank.MockAuth, :authenticate_user, fn user, _password ->
      {:ok, %BookBank.User{username: user, roles: ["admin"]}}
    end)

    expect(BookBankWeb.Utils.MockJwt, :make_token, fn _user, _roles -> {:ok, "shit's good"} end)

    conn =
      json_req(conn, &post/3, "/api/accounts/login", %{"username" => "admin", "password" => "hunter2"})

    assert %{"token" => "shit's good"} = conn |> Phoenix.ConnTest.json_response(:ok)
    assert conn.resp_cookies["X-Auth-Token"].value == "shit's good"
  end

  test "POST /api/accounts/login invalid credentials", %{conn: conn} do
    expect(BookBank.MockAuth, :authenticate_user, fn _user, _password ->
      {:error, :does_not_exist}
    end)

    conn =
      json_req(conn, &post/3, "/api/accounts/login", %{"username" => "admin", "password" => "hunter2"})

    assert %{"token" => nil} = conn |> Phoenix.ConnTest.json_response(:unauthorized)
    assert not (conn.resp_cookies |> Map.has_key?("X-Auth-Token"))
  end

  test "POST /api/accounts/login invalid body", %{conn: conn} do
    conn = json_req(conn, &post/3, "/api/accounts/login", %{"username" => "admin"})

    assert %{"token" => nil} = conn |> Phoenix.ConnTest.json_response(:bad_request)
    assert not (conn.resp_cookies |> Map.has_key?("X-Auth-Token"))
  end

  test "POST /api/accounts/create success", %{conn: conn} do
    expect(BookBank.MockAuth, :create_user, fn user, _password, roles ->
      {:ok, %BookBank.User{username: user, roles: roles}}
    end)

    conn =
      with_token(conn, "admin", ["admin"])
      |> json_req(&post/3, "/api/accounts/create", %{
        "username" => "newuser",
        "roles" => ["librarian"],
        "password" => "hunter2"
      })

    assert %{} = conn |> json_response(:created)
  end

  test "POST /api/accounts/create existing user", %{conn: conn} do
    expect(BookBank.MockAuth, :create_user, fn user, _password, roles ->
      {:error, :user_exists}
    end)

    conn =
      with_token(conn, "admin", ["admin"])
      |> json_req(&post/3, "/api/accounts/create", %{
        "username" => "newuser",
        "roles" => ["librarian"],
        "password" => "hunter2"
      })

    assert %{} = conn |> json_response(:conflict)
  end
end
