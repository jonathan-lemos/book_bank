defmodule BookBankWeb.Utils do
  @type ok_status :: :ok | :created
  @type error_status ::
          :bad_request | :internal_server_error | :conflict | :unauthorized | :forbidden
  @type status :: ok_status() | error_status()

  @spec status_to_string(status()) :: String.t()
  def status_to_string(s) do
    case s do
      :ok -> "OK"
      :created -> "Created"
      :bad_request -> "Bad Request"
      :internal_server_error -> "Internal Server Error"
      :conflict -> "Conflict"
      :unauthorized -> "Unauthorized"
      :forbidden -> "Forbidden"
    end
  end

  @spec status_to_string(status()) :: integer()
  def status_to_number(s) do
    case s do
      :ok -> 200
      :created -> 201
      :bad_request -> 400
      :internal_server_error -> 500
      :conflict -> 409
      :unauthorized -> 401
      :forbidden -> 403
    end
  end

  defp process_opts(conn, [], extra) do
    {:ok, conn, extra}
  end

  defp get_jwt(conn) do
    case conn |> Plug.Conn.get_req_header("authorization") do
      ["Bearer " <> val] ->
        {conn, val}

      _ ->
        nconn = conn |> Plug.Conn.fetch_cookies()
        {nconn, nconn |> Map.get("req_cookies") |> Map.get("X-Auth-Token")}
    end
  end

  defp verify_token(jwt, type) do
    case BookBankWeb.Utils.Auth.verify_token(jwt) do
      {:ok, claims} ->
        case type do
          :any ->
            {:ok, claims}

          list = [] ->
            %{"roles" => actual = []} = claims

            if Enum.any?(list, fn x -> x in actual end) do
              {:ok, claims}
            else
              {:error, :forbidden, "The user does not have any of the following roles: #{list}."}
            end
        end

      {:error, error} ->
        {:error, :unauthorized, error}
    end
  end

  defp process_opts(conn, [{:authentication, type} | tail], extra) do
    {conn, jwt} = get_jwt(conn)

    jwt_res =
      case jwt do
        x when is_binary(x) -> verify_token(jwt, type)
        nil -> {:error, :unauthorized, "No authentication token was given."}
      end

    case jwt_res do
      {:ok, claims} ->
        process_opts(conn, tail, Map.put(extra, :claims, claims))

      {:error, _, _} = err ->
        err
    end
  end

  defp process_opts({:error, status, error}, _, _) do
    {:error, status, error}
  end

  defp process_opts(conn, list) do
    process_opts(conn, list, %{})
  end

  defp with_valid_opts({:ok, conn, extra}, params, func) do
    try do
      case func.(conn, params, extra) do
        {:ok, status, %{} = map} ->
          conn
          |> Plug.Conn.put_status(status)
          |> Phoenix.Controller.json(map)

        {:ok, status} ->
          conn
          |> Plug.Conn.put_status(status)
          |> Phoenix.Controller.json(%{
            status: status_to_number(status),
            response: status_to_string(status)
          })

        :ok ->
          conn
          |> Plug.Conn.put_status(:ok)
          |> Phoenix.Controller.json(%{status: 200, response: status_to_string(:ok)})

        {:error, status, %{} = map} ->
          conn
          |> Plug.Conn.put_status(status)
          |> Phoenix.Controller.json(map)

        {:error, status} ->
          conn
          |> Plug.Conn.put_status(status)
          |> Phoenix.Controller.json(%{
            status: status_to_number(status),
            response: status_to_string(status)
          })
      end
    rescue
      e ->
        conn
        |> Plug.Conn.put_status(:internal_server_error)
        |> Phoenix.Controller.json(%{
          status: 500,
          response: "Internal Server Error",
          message: e.message
        })
    end
  end

  defp with_valid_opts({:error, status, error}, _, _) do
    {:error, status, error}
  end

  @spec with(
          Plug.Conn.t(),
          %{String.t() => term()},
          list({:authentication, list(String.t()) | :any}),
          (() -> {:error, error_status(), %{String.t() => String.t()}}
                 | {:error, error_status()}
                 | {:ok, ok_status(), %{String.t() => String.t()}}
                 | {:ok, ok_status()}
                 | :ok)
        ) :: Plug.Conn.t()
  def with(conn, params, opts \\ [], func) do
    process_opts(conn, opts) |> with_valid_opts(params, func)
  end
end
