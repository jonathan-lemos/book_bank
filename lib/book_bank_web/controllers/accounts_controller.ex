defmodule BookBankWeb.AccountsController do
  use BookBankWeb, :controller

  @spec post_login(Plug.Conn.t(), %{String.t() => term()}) :: Plug.Conn.t()
  def post_login(conn, %{username: un, password: pw}) when is_binary(un) and is_binary(pw) do
    BookBankWeb.Utils.with(conn, [], fn conn, _extra ->
      case BookBank.MongoAuth.authenticate_user(un, pw) do
        {:ok, %BookBank.User{username: username, roles: roles}} ->
          {:ok, jwt} = BookBankWeb.Utils.Auth.make_token(username, roles)

          conn =
            conn
            |> Plug.Conn.put_resp_cookie("X-Auth-Token", jwt,
              max_age: BookBankWeb.Utils.Auth.Token.token_lifetime_seconds(),
              http_only: true,
              secure: true
            )

          {conn, {:ok, :ok, %{token: jwt}}}

        {:error, _} ->
          {conn, {:error, :unauthorized, %{token: nil}}}
      end
    end)
  end

  def post_login(conn, _) do
    BookBankWeb.Utils.with(conn, [], fn conn, _extra ->
      {conn,
       {:error, :bad_request,
        %{token: nil, response: "The 'username' and 'password' keys are required to be strings."}}}
    end)
  end

  defp post_create_process(%{username: username, password: password, roles: roles}) do
    case BookBank.MongoAuth.create_user(username, password, roles) do
      {:ok, _} -> {:ok, :created}
      {:error, msg} -> {:error, :conflict, msg}
    end
  end

  defp post_create_process(%{username: _, password: _} = map) do
    post_create_process(Map.put(map, :roles, []))
  end

  defp post_create_process(_) do
    {:error, :bad_request,
     %{response: "This endpoint requires 'username' and 'password' keys in the request body."}}
  end

  @spec post_create(Plug.Conn.t(), %{String.t() => term()}) :: Plug.Conn.t()
  def post_create(conn, params) do
    BookBankWeb.Utils.with(conn, [authentication: ["admin"]], fn conn, _extra ->
      {conn, post_create_process(params)}
    end)
  end

  @spec get_roles(Plug.Conn.t(), %{String.t() => term()}) :: Plug.Conn.t()
  def get_roles(conn, _params) do
    BookBankWeb.Utils.with(conn, [authentication: ["admin"]], fn conn, _extra ->
      {conn, {:ok, BookBank.Auth.roles()}}
    end)
  end

  @spec get_role_accounts(Plug.Conn.t(), %{String.t() => term()}) :: Plug.Conn.t()
  def get_role_accounts(conn, params) do
    BookBankWeb.Utils.with(conn, [authentication: ["admin"]], fn conn, _extra ->
      obj =
        with %{"role" => role} <- params do
          if role in BookBank.Auth.roles() do
            {:ok, :ok, BookBank.MongoAuth.users_with_role(role)}
          else
            {:error, :not_found}
          end
        else
          _ -> {:error, :not_found}
        end

      {conn, obj}
    end)
  end

  def get_user_roles(conn, %{"username" => user}) do
    BookBankWeb.Utils.with(
      conn,
      [authentication: [{:current_user, user}, "admin"]],
      fn conn, _extra ->
        obj =
          with {:ok, %BookBank.User{roles: roles}} <- BookBank.MongoAuth.get_user(user) do
            {:ok, :ok, %{"roles" => roles}}
          else
            {:error, :does_not_exist} ->
              {:error, :not_found, "The user '#{user}' does not exist."}

            {:error, e} ->
              {:error, :internal_server_error, e}
          end

        {conn, obj}
      end
    )
  end

  defp add_user_roles_list(list) when is_list(list) do
    if Enum.all?(list, &is_binary/1) do
      if Enum.all?(list, &(&1 in BookBank.Auth.roles())) do
        {:ok, list |> Enum.map(&{:add_role, &1})}
      else
        {:error,
         "The following contents of 'add' are not valid roles: #{
           IO.inspect(Enum.filter(list, &(&1 not in BookBank.Auth.roles())))
         }"}
      end
    else
      {:error, "The contents of 'add' must all be strings."}
    end
  end

  defp add_user_roles_list(_) do
    {:error, "'add' must be an array of strings."}
  end

  defp remove_user_roles_list(list) when is_list(list) do
    if Enum.all?(list, &is_binary/1) do
      {:ok, list |> Enum.map(&{:remove_role, &1})}
    else
      {:error, "The contents of 'remove' must all be strings."}
    end
  end

  defp remove_user_roles_list(_) do
    {:error, "'remove' must be an array of strings."}
  end

  defp set_user_roles_list(list) when is_list(list) do
    if Enum.all?(list, &is_binary/1) do
      if Enum.all?(list, &(&1 in BookBank.Auth.roles())) do
        {:ok, {:set_roles, list}}
      else
        {:error,
         "The following contents of 'roles' are not valid roles: #{
           IO.inspect(Enum.filter(list, &(&1 not in BookBank.Auth.roles())))
         }"}
      end
    else
      {:error, "'roles' must be an array of strings."}
    end
  end

  def put_user_roles(conn, %{"username" => user, "roles" => roles}) do
    BookBankWeb.Utils.with(conn, [authentication: ["admin"]], fn conn, _extra ->
      obj =
        with {:ok, tup} <- set_user_roles_list(roles) do
          case BookBank.MongoAuth.update_user(user, [tup]) do
            :ok ->
              {:ok, :ok}

            {:error, :does_not_exist} ->
              {:error, :not_found, "The user '#{user}' does not exist."}

            {:error, e} ->
              {:error, :bad_request, e}
          end
        else
          {:error, e} -> {:error, :bad_request, e}
        end

      {conn, obj}
    end)
  end

  def put_user_roles(conn, %{"username" => _user}) do
    BookBankWeb.Utils.with(conn, [authentication: ["admin"]], fn conn, _extra ->
      {conn, {:error, :bad_request, "Expected 'roles' key in request body."}}
    end)
  end

  @spec patch_user_roles(Plug.Conn.t(), %{String.t() => term()}) :: Plug.Conn.t()
  def patch_user_roles(conn, %{"username" => user, "remove" => remove, "add" => add}) do
    BookBankWeb.Utils.with(
      conn,
      [authentication: ["admin"]],
      fn conn, _extra ->
        obj =
          with {:ok, add} <- add_user_roles_list(add),
               {:ok, remove} <-
                 remove_user_roles_list(remove) do
            case BookBank.MongoAuth.update_user(user, add ++ remove) do
              :ok ->
                {:ok, :ok}

              {:error, :does_not_exist} ->
                {:error, :not_found, "The user '#{user}' does not exist."}

              {:error, e} ->
                {:error, :bad_request, e}
            end
          else
            {:error, e} -> {:error, :bad_request, e}
          end

        {conn, obj}
      end
    )
  end

  def patch_user_roles(conn, %{"username" => _, "remove" => _} = params) do
    patch_user_roles(conn, Map.put(params, "add", []))
  end

  def patch_user_roles(conn, %{"username" => _, "add" => _} = params) do
    patch_user_roles(conn, Map.put(params, "remove", []))
  end

  def patch_user_roles(conn, %{"username" => _}) do
    BookBankWeb.Utils.with(conn, [authentication: ["admin"]], fn conn, _extra ->
      {conn,
       {:ok, :ok, %{"response" => "Neither 'remove' nor 'add' lists given, so nothing changed."}}}
    end)
  end

  def put_user_password(conn, %{"username" => user, "password" => pw}) do
    BookBankWeb.Utils.with(conn, [authentication: [{:current_user, user}, "admin"]], fn conn, _extra ->
      obj =
        case BookBank.MongoAuth.update_user(user, password: pw) do
          :ok ->
            {:ok, :ok}

          {:error, :does_not_exist} ->
            {:error, :not_found, "The user '#{user}' does not exist."}

          {:error, e} ->
            {:error, :bad_request, e}
        end

      {conn, obj}
    end)
  end

  def put_user_password(conn, %{"username" => user}) do
    BookBankWeb.Utils.with(conn, [authentication: [{:current_user, user}, "admin"]], fn conn, _extra ->
      {conn, {:error, :bad_request, "The request object requires {'password': string}"}}
    end)
  end

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
