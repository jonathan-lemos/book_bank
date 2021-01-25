defmodule Test.Utils do
  @spec with_token(Plug.Conn.t(), :invalid) :: Plug.Conn.t()
  def with_token(conn, :invalid) do
    Mox.expect(BookBankWeb.Utils.MockJwt, :verify_token, fn _ ->
      {:error, "Mock: invalid token"}
    end)

    conn
  end

  @spec with_token(Plug.Conn.t(), String.t(), list(String.t())) :: Plug.Conn.t()
  def with_token(conn, user, roles \\ []) do
    Mox.expect(BookBankWeb.Utils.MockJwt, :verify_token, fn _ ->
      {:ok, %{"iat" => 0, "sub" => user, "roles" => roles}}
    end)

    conn |> Plug.Test.put_req_cookie("X-Auth-Token", "test") |> Plug.Conn.fetch_cookies()
  end

  def json_req(conn, func, route, body) do
    conn = conn |> Plug.Conn.put_req_header("content-type", "application/json")
    body = Jason.encode!(body)

    apply(func, [conn, route, body])
  end
end
