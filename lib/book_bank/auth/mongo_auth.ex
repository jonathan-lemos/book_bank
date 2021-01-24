defmodule BookBank.MongoAuth do
  @behaviour BookBank.Auth

  def authenticate_user(username, password) do
    case Mongo.find_one(:mongo, "users", %{username: username}, read_concern: "majority") do
      %{username: un, password: pw, roles: roles} ->
        if Argon2.verify_pass(password, pw) do
          {:ok, %BookBank.User{username: un, roles: roles}}
        else
          {:error, :wrong_password}
        end

      _ ->
        {:error, :does_not_exist}
    end
  end

  def create_user(username, password, roles) do
    roles = roles |> Enum.filter(fn x -> x in BookBank.Auth.roles() end)

    user = %{
      username: username,
      password: password,
      roles: roles
    }

    case Mongo.insert_one(:mongo, "users", user, write_concern: BookBank.Utils.Mongo.write_concern_majority()) do
      {:ok, %Mongo.InsertOneResult{acknowledged: true, inserted_id: _}} ->
        {:ok, %BookBank.User{username: username, roles: roles}}

      {:error, %{message: msg}} ->
        {:error, msg}
    end
  end

  def get_user(username) do
    case Mongo.find_one(:mongo, "users", %{username: username}, read_concern: "majority") do
      %{username: un, password: _, roles: r} ->
        {:ok, %BookBank.User{username: un, roles: r}}

      nil ->
        {:error, :does_not_exist}
    end
  end

  defp update(obj, []) do
    obj
  end

  defp update(obj, [head | tail]) do
    # the func takes obj[key][selector] and outputs its new value
    obj_mutate_selector = fn selector, key, default, func ->
      selector_map = Map.get(obj, selector, %{})
      key_obj = Map.get(selector_map, key, default)

      new_key_obj = func.(key_obj)
      new_selector_map = Map.put(selector_map, key, new_key_obj)

      Map.put(obj, selector, new_selector_map)
    end

    new_obj =
      case head do
        {:set_roles, roles} ->
          obj_mutate_selector.("$set", "roles", [], fn _ -> roles end)

        {:add_role, role} ->
          obj_mutate_selector.("$addToSet", "roles", [], &[role | &1])

        {:add_roles, roles} ->
          obj_mutate_selector.("$addToSet", "roles", [], &(roles ++ &1))

        {:remove_role, role} ->
          obj_mutate_selector.("$pullAll", "roles", [], &[role | &1])

        {:remove_roles, roles} ->
          obj_mutate_selector.("$pullAll", "roles", [], &(roles ++ &1))

        {:password, pw} ->
          obj_mutate_selector.("$set", "password", "", fn _ -> Argon2.hash_pwd_salt(pw) end)
      end

    update(new_obj, tail)
  end

  defp update(updates) do
    update(%{}, updates)
  end

  def update_user(username, updates) do
    obj = update(updates)

    case Mongo.update_one(:mongo, "users", %{username: username}, obj, write_concern: BookBank.Utils.Mongo.write_concern_majority()) do
      {:ok, %Mongo.UpdateResult{acknowledged: true, matched_count: n}} when n > 0 ->
        :ok

      {:ok, %Mongo.UpdateResult{acknowledged: true}} ->
        {:error, :does_not_exist}

      {:ok, %Mongo.UpdateResult{acknowledged: false}} ->
        {:error, "The update request was not acknowledged."}

      {:error, error} ->
        {:error, error}
    end
  end

  def delete_user(username) do
    case Mongo.delete_many(:mongo, "users", %{username: username}, write_concern: BookBank.Utils.Mongo.write_concern_majority()) do
      {:ok, %Mongo.DeleteResult{acknowledged: true, deleted_count: n}} when n > 0 -> :ok
      {:ok, %Mongo.DeleteResult{acknowledged: true, deleted_count: 0}} -> {:error, :does_not_exist}
      {:ok, _} -> {:error, "The delete was not acknowledged by the server"}
      {:error, error} -> {:error, error}
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
