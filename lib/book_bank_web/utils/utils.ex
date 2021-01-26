defmodule BookBankWeb.Utils do
  @jwt_service Application.get_env(:book_bank, BookBankWeb.Utils.JwtBehavior)

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

  def status_code_to_atom(s) do
    case s do
      200 -> :ok
      201 -> :created
      400 -> :bad_request
      500 -> :internal_server_error
      409 -> :conflict
      401 -> :unauthorized
      403 -> :forbidden
      404 -> :not_found
      _ -> :internal_server_error
    end
  end

  defp get_jwt(conn) do
    case conn |> Plug.Conn.get_req_header("authorization") do
      ["Bearer " <> val] ->
        {conn, val}

      _ ->
        nconn = conn |> Plug.Conn.fetch_cookies()
        {nconn, nconn.req_cookies["X-Auth-Token"]}
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

  defp verify_token(conn, jwt, type) do
    case @jwt_service.verify_token(jwt) do
      {:ok, claims} ->
        case type do
          :any ->
            {:ok, claims}

          auth_list when is_list(auth_list) ->
            %{"sub" => username, "roles" => roles} = claims

            if verify_claims_list(username, roles, auth_list) do
              {:ok, claims}
            else
              {:error, conn, :forbidden,
               "The user does not have any of the following roles: #{Kernel.inspect(auth_list)}."}
            end
        end

      {:error, error} ->
        {:error, conn, :unauthorized, error}
    end
  end

  defp process_opts(conn, [], extra) do
    {:ok, conn, extra}
  end

  defp process_opts(conn, [{:authentication, type} | tail], extra) do
    {conn, jwt} = get_jwt(conn)

    jwt_res =
      case jwt do
        x when is_binary(x) -> verify_token(conn, jwt, type)
        nil -> {:error, conn, :unauthorized, "No authentication token was given."}
      end

    case jwt_res do
      {:ok, claims} ->
        process_opts(conn, tail, Map.put(extra, :claims, claims))

      {:error, _, _, _} = err ->
        err
    end
  end

  defp process_opts({:error, conn, status, error}, _, _) do
    {:error, conn, status, error}
  end

  defp process_opts(conn, list) do
    process_opts(conn, list, %{})
  end

  defp default_map(status) do
    %{status: status_to_number(status), response: status_to_string(status)}
  end

  defp with_valid_opts({:ok, conn, extra}, func) do
    try do
      case func.(conn, extra) do
        {conn, {:ok, status, :stream, stream, list}} when is_list(list) and (is_atom(status) or is_integer(status)) ->
          conn
          |> Plug.Conn.put_status(status)
          |> Phoenix.Controller.send_download({:binary, stream}, list)

        {conn, {:ok, status, :stream, stream}} when is_atom(status) or is_integer(status) ->
          conn
          |> Plug.Conn.put_status(status)
          |> Phoenix.Controller.send_download({:binary, stream})

        {conn, {:ok, status, map}} when is_map(map) and (is_atom(status) or is_integer(status)) ->
          conn
          |> Plug.Conn.put_status(status)
          |> Phoenix.Controller.json(Map.merge(default_map(status), map))

        {conn, {:ok, status, str}} when is_binary(str) and (is_atom(status) or is_integer(status)) ->
          conn
          |> Plug.Conn.put_status(status)
          |> Phoenix.Controller.json(Map.put(default_map(status), "response", str))

        {conn, {:ok, status}} when is_atom(status) or is_integer(status) ->
          conn
          |> Plug.Conn.put_status(status)
          |> Phoenix.Controller.json(default_map(status))

        {conn, :ok} ->
          conn
          |> Plug.Conn.put_status(:ok)
          |> Phoenix.Controller.json(default_map(:ok))

        {conn, {:error, status, map}} when is_map(map) and (is_atom(status) or is_integer(status)) ->
          conn
          |> Plug.Conn.put_status(status)
          |> Phoenix.Controller.json(Map.merge(default_map(status), map))

        {conn, {:error, status, str}} when is_binary(str) and (is_atom(status) or is_integer(status)) ->
          conn
          |> Plug.Conn.put_status(status)
          |> Phoenix.Controller.json(Map.put(default_map(status), "response", str))

        {conn, {:error, status}} when is_atom(status) or is_integer(status) ->
          conn
          |> Plug.Conn.put_status(status)
          |> Phoenix.Controller.json(default_map(status))

        {conn, res} ->
          conn
          |> Plug.Conn.put_status(:internal_server_error)
          |> Phoenix.Controller.json(default_map(:internal_server_error) |> Map.put("message", "Function '#{Kernel.inspect func}' produced an invalid response '#{Kernel.inspect res}'. This is a bug."))

        _ ->
          conn
          |> Plug.Conn.put_status(:internal_server_error)
          |> Phoenix.Controller.json(default_map(:internal_server_error) |> Map.put("message", "Function '#{Kernel.inspect func}' did not include the connection in the response. This is a bug."))
      end
    rescue
      e ->
        conn
        |> Plug.Conn.put_status(:internal_server_error)
        |> Phoenix.Controller.json(
          Map.put(default_map(:internal_server_error), "message", "#{Exception.format(:error, e)}")
        )
    end
  end

  defp with_valid_opts({:error, conn, status, error}, _) do
    conn =
      if status == :unauthorized do
        conn
        |> Plug.Conn.put_resp_cookie("X-Auth-Token", "", max_age: 0, http_only: true, secure: true)
      else
        conn
      end

    conn
    |> Plug.Conn.put_status(status)
    |> Phoenix.Controller.json(Map.put(default_map(status), "error", error))
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
              | {:ok, ok_status(), :stream, Stream.t(),
                 list(
                   {:content_type, String.t()}
                   | {:filename, String.t()}
                   | {:disposition, :attachment | :inline}
                 )}
              | {:ok, ok_status(), :stream, Stream.t()}
              | :ok})
        ) :: Plug.Conn.t()
  def with(conn, opts, func) do
    process_opts(conn, opts) |> with_valid_opts(func)
  end
end
