defmodule BookBank.MongoAuth do
  @behaviour BookBank.AuthBehavior

  def authenticate_user(username, password) do
    case Mongo.find_one(:mongo, "users", %{username: username},
           read_concern: BookBank.Utils.Mongo.read_concern_majority()
         ) do
      %{"username" => un, "password" => pw, "roles" => roles} ->
        IO.inspect(pw)
        if Argon2.verify_pass(password, pw) do
          {:ok, %BookBank.User{username: un, roles: roles}}
        else
          {:error, :wrong_password}
        end

      {:error, %Mongo.Error{message: msg}} ->
        {:error, msg}

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

    case Mongo.insert_one(:mongo, "users", user,
           write_concern: BookBank.Utils.Mongo.write_concern_majority()
         ) do
      {:ok, %Mongo.InsertOneResult{acknowledged: true, inserted_id: _}} ->
        {:ok, %BookBank.User{username: username, roles: roles}}

      {:error, %{message: msg}} ->
        {:error, msg}
    end
  end

  def get_user(username) do
    case Mongo.find_one(:mongo, "users", %{username: username},
           read_concern: BookBank.Utils.Mongo.read_concern_majority()
         ) do
      %{"username" => un, "password" => _, "roles" => r} ->
        {:ok, %BookBank.User{username: un, roles: r}}

      {:error, %Mongo.Error{message: message}} ->
        {:error, message}

      nil ->
        {:error, :does_not_exist}
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
          BookBank.Utils.Mongo.object_merge(obj, %{"$set" => %{"password" => updates[:set_password] |> Argon2.hash_pwd_salt()}})
        else
          obj
        end

      case Mongo.update_one(:mongo, "users", %{username: username}, obj) do
        {:ok, %Mongo.UpdateResult{acknowledged: true, matched_count: n}} when n > 0 -> :ok
        {:ok, %Mongo.UpdateResult{acknowledged: true}} -> {:error, :does_not_exist}
        {:ok, %Mongo.UpdateResult{}} -> {:error, "The update was not acknowledged"}
        {:error, %Mongo.Error{message: msg}} -> {:error, msg}
      end
    else
      e -> e
    end
  end

  def delete_user(username) do
    case Mongo.delete_many(:mongo, "users", %{username: username},
           write_concern: BookBank.Utils.Mongo.write_concern_majority()
         ) do
      {:ok, %Mongo.DeleteResult{acknowledged: true, deleted_count: n}} when n > 0 ->
        :ok

      {:ok, %Mongo.DeleteResult{acknowledged: true, deleted_count: 0}} ->
        {:error, :does_not_exist}

      {:ok, _} ->
        {:error, "The delete was not acknowledged by the server"}

      {:error, error} ->
        {:error, error}
    end
  end

  def users_with_role(role) do
    list =
      Mongo.find(:mongo, "users", %{roles: role}, read_concern: "majority")
      |> Stream.map(fn x -> %BookBank.User{username: x["username"], roles: x["roles"]} end)
      |> Enum.to_list()

    {:ok, list}
  end
end
