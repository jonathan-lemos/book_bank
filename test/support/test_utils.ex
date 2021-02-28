defmodule Test.Utils do
  @moduledoc false

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

  @spec json_req(
          Plug.Conn.t(),
          (Plug.Conn.t(), String.t() | atom, any -> Plug.Conn.t()),
          String.t() | atom,
          any
        ) :: Plug.Conn.t()
  def json_req(conn, func, route, body) do
    conn = conn |> Plug.Conn.put_req_header("content-type", "application/json")
    body = Jason.encode!(body)

    apply(func, [conn, route, body])
  end

  @spec multipart_formdata_req(
          Plug.Conn.t(),
          (Plug.Conn.t(), String.t() | atom, any -> Plug.Conn.t()),
          String.t() | atom,
          %{
            String.t() =>
              String.t() | {String.t(), [filename: String.t(), content_type: String.t()]}
          }
        ) :: Plug.Conn.t()
  def multipart_formdata_req(conn, func, route, body) do
    conn = conn |> Plug.Conn.put_req_header("content-type", "multipart/form-data; boundary=12345")

    body =
      (Enum.map(body, fn
         {key, {content, filename: filename, content_type: content_type}} ->
           "
--12345\r
Content-Disposition: form-data; name=\"#{key}\"; filename=\"#{filename}\"\r
Content-Type: #{content_type}\r
\r
#{content}\r
" |> String.trim()

         {key, content} ->
           "
--12345\r
Content-Disposition: form-data; name=\"#{key}\"\r
\r
#{content}\r
          " |> String.trim()
       end)
       |> Enum.join("\r\n")) <> "\r\n--12345--\r\n"

    apply(func, [conn, route, body])
  end

  @spec expect_time(list(integer) | integer) :: atom
  def expect_time(time) when is_integer(time) do
    Mox.expect(BookBankWeb.Utils.MockJwtTime, :current_time, fn -> time end)
  end

  def expect_time(list) when is_list(list) do
    Enum.each(list, &expect_time/1)
  end

  @spec expect_lifetime(integer) :: :ok
  def expect_lifetime(time) when is_integer(time) do
    Application.put_env(
      :book_bank,
      BookBankWeb.Utils.Jwt.Token,
      Application.get_env(:book_bank, BookBankWeb.Utils.Jwt.Token)
      |> Keyword.merge(lifetime_seconds: time)
    )
  end
end

defmodule Test.StubTime do
  @behaviour Joken.CurrentTime
  use Agent

  def start_link() do
    Agent.start_link(fn -> 0 end, name: __MODULE__)
  end

  @spec current_time :: pos_integer()
  def current_time() do
    Agent.get(__MODULE__, & &1)
  end

  @spec set_current_time(pos_integer()) :: :ok
  def set_current_time(number) do
    Agent.update(__MODULE__, fn _ -> number end)
  end
end
