defmodule BookBank.MongoAuth do
  @behaviour BookBank.AuthBehavior

  alias BookBank.Utils.Mongo, as: Utils

  def authenticate_user(username, password) do
    case Utils.find("users", %{username: username}, read_concern: Utils.read_concern_majority()) do
      {:ok, %{"username" => un, "password" => pw, "roles" => roles}} ->
        if Argon2.verify_pass(password, pw) do
          {:ok, %BookBank.User{username: un, roles: roles}}
        else
          {:error, :wrong_password}
        end

      {:ok, _doc} ->
        {:error, :does_not_exist}

      nil ->
        {:error, :does_not_exist}
    end
  end

  def create_user(username, password, roles) do
    roles = roles |> Enum.filter(fn x -> x in BookBank.AuthBehavior.roles() end)

    user = %{
      username: username,
      password: password |> Argon2.hash_pwd_salt(),
      roles: roles
    }

    case Utils.insert("users", user, write_concern: Utils.write_concern_majority()) do
      {:ok, _id} ->
        {:ok, %BookBank.User{username: username, roles: roles}}

      {:error, msg} ->
        {:error, msg}
    end
  end

  def get_user(username) do
    case Utils.find("users", %{username: username}, read_concern: Utils.read_concern_majority()) do
      {:ok, %{"username" => un, "password" => _, "roles" => r}} ->
        {:ok, %BookBank.User{username: un, roles: r}}

      {:ok, _doc} ->
        {:error, :does_not_exist}

      {:error, e} ->
        {:error, e}
    end
  end

  def update_user(username, updates) do
    with {:ok, %BookBank.User{roles: roles}} <- get_user(username) do
      roles =
        roles
        |> BookBank.Utils.Set.minus(updates[:remove_roles] || [])
        |> BookBank.Utils.Set.union(updates[:add_roles] || [])

      obj = %{"$set" => %{"roles" => roles}}

      obj =
        if updates[:set_password] !== nil do
          BookBank.Utils.Mongo.object_merge(obj, %{
            "$set" => %{"password" => updates[:set_password] |> Argon2.hash_pwd_salt()}
          })
        else
          obj
        end

      Utils.replace("users", %{username: username}, obj, write_concern: Utils.write_concern_majority())
    else
      e -> e
    end
  end

  def delete_user(username) do
    Utils.delete("users", %{username: username}, write_concern: Utils.write_concern_majority())
  end

  def users_with_role(role) do
    list =
      Mongo.find(:mongo, "users", %{roles: role}, read_concern: Utils.read_concern_majority())
      |> Stream.map(fn x -> %BookBank.User{username: x["username"], roles: x["roles"]} end)
      |> Enum.to_list()

    {:ok, list}
  end
end
