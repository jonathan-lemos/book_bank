defmodule BookBankWeb.AccountsControllerTest do
  use BookBankWeb.ConnCase, async: true
  import Mox

  setup :verify_on_exit!

  def json_post(conn, route, body) do
    conn |> Plug.Conn.put_req_header("content-type", "application/json") |> post(route, Jason.encode!(body))
  end

  test "POST /api/accounts/login success", %{conn: conn} do
    expect(BookBank.MockAuth, :authenticate_user, fn user, _password ->
      {:ok, %BookBank.User{username: user, roles: ["admin"]}}
    end)

    expect(BookBankWeb.Utils.MockAuth, :make_token, fn _user, _roles -> {:ok, "shit's good"} end)

    conn = json_post(conn, "/api/accounts/login", %{"username" => "admin", "password" => "hunter2"})

    assert %{"token" => "shit's good"} = conn |> Phoenix.ConnTest.json_response(:ok)
    assert conn.resp_cookies["X-Auth-Token"].value == "shit's good"
  end
end
