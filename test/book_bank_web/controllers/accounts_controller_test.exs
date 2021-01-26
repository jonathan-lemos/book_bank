defmodule BookBankWeb.AccountsControllerTest do
  use BookBankWeb.ConnCase, async: true
  import Mox
  import Test.Utils

  setup :verify_on_exit!

  test "POST /api/accounts/login success", %{conn: conn} do
    expect(BookBank.MockAuth, :authenticate_user, fn user, _password ->
      {:ok, %BookBank.User{username: user, roles: ["admin"]}}
    end)

    expect(BookBankWeb.Utils.MockJwt, :make_token, fn "admin", ["admin"] -> {:ok, "shit's good"} end)

    conn =
      json_req(conn, &post/3, "/api/accounts/login", %{
        "username" => "admin",
        "password" => "hunter2"
      })

    assert %{"token" => "shit's good"} = conn |> Phoenix.ConnTest.json_response(:ok)
    assert conn.resp_cookies["X-Auth-Token"].value == "shit's good"
  end

  test "POST /api/accounts/login invalid credentials", %{conn: conn} do
    expect(BookBank.MockAuth, :authenticate_user, fn "admin", "hunter2" ->
      {:error, :does_not_exist}
    end)

    conn =
      json_req(conn, &post/3, "/api/accounts/login", %{
        "username" => "admin",
        "password" => "hunter2"
      })

    assert %{"token" => nil} = conn |> Phoenix.ConnTest.json_response(:unauthorized)
    assert not (conn.resp_cookies |> Map.has_key?("X-Auth-Token"))
  end

  test "POST /api/accounts/login invalid body", %{conn: conn} do
    conn = json_req(conn, &post/3, "/api/accounts/login", %{"username" => "admin"})

    assert %{"token" => nil} = conn |> Phoenix.ConnTest.json_response(:bad_request)
    assert not (conn.resp_cookies |> Map.has_key?("X-Auth-Token"))
  end

  test "POST /api/accounts/create success", %{conn: conn} do
    expect(BookBank.MockAuth, :create_user, fn "newuser", "hunter2", ["librarian"] ->
      {:ok, %BookBank.User{username: "newuser", roles: ["librarian"]}}
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
    expect(BookBank.MockAuth, :create_user, fn "newuser", "hunter2", ["librarian"] ->
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

  test "POST /api/accounts/create not admin", %{conn: conn} do
    conn =
      with_token(conn, "user")
      |> json_req(&post/3, "/api/accounts/create", %{
        "username" => "newuser",
        "roles" => ["librarian"],
        "password" => "hunter2"
      })

    assert %{} = conn |> json_response(:forbidden)
  end

  test "POST /api/accounts/create bad request", %{conn: conn} do
    conn =
      with_token(conn, "admin", ["admin"])
      |> json_req(&post/3, "/api/accounts/create", %{
        "username" => "newuser",
        "roles" => ["librarian"]
      })

    assert %{} = conn |> json_response(:bad_request)
  end

  test "GET /api/accounts/roles", %{conn: conn} do
    conn =
      with_token(conn, "admin", ["admin"])
      |> get("/api/accounts/roles")

    roles = BookBank.AuthBehavior.roles()
    assert %{"roles" => ^roles} = conn |> json_response(:ok)
  end

  test "GET /api/accounts/roles/admin success", %{conn: conn} do
    users = ["user1", "user2"]

    expect(BookBank.MockAuth, :users_with_role, fn "admin" ->
      {:ok, Enum.map(users, &%BookBank.User{username: &1, roles: ["admin"]})}
    end)

    conn =
      with_token(conn, "admin", ["admin"])
      |> get("/api/accounts/roles/admin")

    assert %{"users" => ^users} = conn |> json_response(:ok)
  end

  test "GET /api/accounts/users/roles/user1 success", %{conn: conn} do
    expect(BookBank.MockAuth, :get_user, fn "user1" ->
      {:ok, %BookBank.User{username: "user1", roles: ["librarian"]}}
    end)

    conn =
      with_token(conn, "user1", ["librarian"])
      |> get("/api/accounts/users/roles/user1")

    assert %{"roles" => ["librarian"]} = conn |> json_response(:ok)
  end

  test "PUT /api/accounts/users/roles/user1 success", %{conn: conn} do
    expect(BookBank.MockAuth, :update_user, fn "user1", [set_roles: ["admin"]] ->
      :ok
    end)

    conn =
      with_token(conn, "admin", ["admin"])
      |> json_req(&put/3, "/api/accounts/users/roles/user1", %{
        "roles" => ["admin"]
      })

    assert %{} = conn |> json_response(:ok)
  end

  test "PATCH /api/accounts/users/roles/user1 success", %{conn: conn} do
    expect(BookBank.MockAuth, :update_user, fn "user1", [add_role: "admin", remove_role: "librarian"] ->
      :ok
    end)

    conn =
      with_token(conn, "admin", ["admin"])
      |> json_req(&patch/3, "/api/accounts/users/roles/user1", %{
        "add" => ["admin"],
        "remove" => ["librarian"]
      })

    assert %{} = conn |> json_response(:ok)
  end

  test "PUT /api/accounts/users/password/user1 success", %{conn: conn} do
    expect(BookBank.MockAuth, :update_user, fn "user1", [password: "hunter2"] ->
      :ok
    end)

    conn =
      with_token(conn, "user1")
        |> json_req(&put/3, "/api/accounts/users/password/user1", %{
          "password" => "hunter2"
        })

    assert %{} = conn |> json_response(:ok)
  end

  test "DELETE /api/accounts/users/user1 success", %{conn: conn} do
    expect(BookBank.MockAuth, :delete_user, fn "user1" -> :ok end)

    conn =
      with_token(conn, "admin", ["admin"])
        |> delete("/api/accounts/users/user1")

    assert %{} = conn |> json_response(:ok)
  end
end
