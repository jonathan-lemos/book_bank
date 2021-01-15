defmodule BookBankWeb.Utils do
  @type ok_status :: :ok | :created
  @type error_status ::
          :bad_request
          | :internal_server_error
          | :conflict
          | :unauthorized
          | :forbidden
          | :not_found
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
      :not_found -> "Not Found"
    end
  end

  @spec status_to_number(status()) :: integer()
  def status_to_number(s) do
    case s do
      :ok -> 200
      :created -> 201
      :bad_request -> 400
      :internal_server_error -> 500
      :conflict -> 409
      :unauthorized -> 401
      :forbidden -> 403
      :not_found -> 404
    end
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

  defp verify_claims_list(username, roles, [head | tail]) do
    matched =
      case head do
        {:current_user, expected_username} -> username == expected_username
        role when is_binary(role) -> role in roles
      end

    if matched do
      true
    else
      verify_claims_list(username, roles, tail)
    end
  end

  defp verify_claims_list(_, _, []) do
    false
  end

  defp verify_token(jwt, type) do
    case BookBankWeb.Utils.Auth.verify_token(jwt) do
      {:ok, claims} ->
        case type do
          :any ->
            {:ok, claims}

          auth_list when is_list(auth_list) ->
            %{"username" => username, "roles" => roles} = claims

            if verify_claims_list(username, roles, auth_list) do
              {:ok, claims}
            else
              {:error, :forbidden,
               "The user does not have any of the following roles: #{IO.inspect(auth_list)}."}
            end
        end

      {:error, error} ->
        {:error, :unauthorized, error}
    end
  end

  defp process_opts(conn, [], extra) do
    {:ok, conn, extra}
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

  defp with_valid_opts({:ok, conn, extra}, func) do
    default_map = fn status ->
      %{status: status_to_number(status), response: status_to_string(status)}
    end

    try do
      case func.(conn, extra) do
        {conn, {:ok, status, map}} when is_map(map) ->
          conn
          |> Plug.Conn.put_status(status)
          |> Phoenix.Controller.json(Map.merge(default_map.(status), map))

        {conn, {:ok, status, str}} when is_binary(str) ->
          conn
          |> Plug.Conn.put_status(status)
          |> Phoenix.Controller.json(Map.put(default_map.(status), "response", str))

        {conn, {:ok, status}} ->
          conn
          |> Plug.Conn.put_status(status)
          |> Phoenix.Controller.json(default_map.(status))

        {conn, :ok} ->
          conn
          |> Plug.Conn.put_status(:ok)
          |> Phoenix.Controller.json(default_map.(:ok))

        {conn, {:error, status, map}} when is_map(map) ->
          conn
          |> Plug.Conn.put_status(status)
          |> Phoenix.Controller.json(Map.merge(default_map.(status), map))

        {conn, {:error, status, str}} when is_binary(str) ->
          conn
          |> Plug.Conn.put_status(status)
          |> Phoenix.Controller.json(Map.put(default_map.(status), "response", str))

        {conn, {:error, status}} ->
          conn
          |> Plug.Conn.put_status(status)
          |> Phoenix.Controller.json(default_map.(status))
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

  defp with_valid_opts({:error, status, error}, _) do
    {:error, status, error}
  end

  @spec with(
          Plug.Conn.t(),
          list({:authentication, list(String.t() | {:current_user, String.t()}) | :any}),
          (Plug.Conn.t(), %{any => any} ->
             {Plug.Conn.t(),
              {:error, error_status(), %{any => any} | String.t()}
              | {:error, error_status()}
              | {:ok, ok_status(), %{any => any} | String.t()}
              | {:ok, ok_status()}
              | :ok})
        ) :: Plug.Conn.t()
  def with(conn, opts, func) do
    process_opts(conn, opts) |> with_valid_opts(func)
  end
end
