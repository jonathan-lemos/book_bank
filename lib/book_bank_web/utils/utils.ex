defmodule BookBankWeb.Utils do
  @type ok_status :: :ok | :created
  @type error_status :: :bad_request | :internal_server_error | :conflict | :unauthorized | :forbidden
  @type status :: ok_status() | error_status()

  @spec status_to_string(status()) :: String.t()
  def status_to_string(s) do
    case s do
      :ok -> "OK"
      :created -> "Created"
      :bad_request -> "Bad Request"
      :internal_server_error -> "Internal Server Error"
      :conflict -> "Conflict"
    end
  end

  defp process_opts(conn, [], extra) do
    {:ok, conn, extra}
  end

  defp process_opts(conn, [{:authentication, type} | tail], extra) do
    case BookBankWeb.Utils.Auth.verify_token() do
      {:ok, claims} ->
        case type do
          :any ->
            process_opts(conn, tail, Map.put(extra, :claims, claims))

          list = [] ->
            %{"roles" => actual = []} = claims

            if Enum.any?(list, fn x -> x in actual end) do
              process_opts(conn, tail, Map.put(extra, :claims, claims))
            else
              {:error, :forbidden, "The user does not have any of the following roles: #{list}."}
            end
        end

      {:error, status, error} ->
        {:error, status, error}
    end
  end

  defp process_opts({:error, error}, _, _) do
    {:error, error}
  end

  defp process_opts(conn, list) do
    process_opts(conn, list, %{})
  end

  defp with_valid_opts({:ok, conn, extra}, params, func) do
    case func.(conn, params, extra) do
      {:ok, status, reason} ->
        Phoenix.Controller.json(conn, %{status: status, reason: reason})
    end
  end

  defp with_valid_opts({:error, error}, _, _) do
    {:error, error}
  end

  @spec with(
          Plug.Conn.t(),
          %{String.t() => term()},
          list({:authentication, list(String.t()) | :any}),
          (() -> {:error, error_status(), String.t()}
                 | {:error, error_status()}
                 | {:ok, ok_status(), String.t()}
                 | {:ok, ok_status()}
                 | :ok)
        ) :: Plug.Conn.t()
  def with(conn, params, opts \\ [], func) do
    process_opts(conn, opts) |> with_valid_opts(params, func)
  end
end
