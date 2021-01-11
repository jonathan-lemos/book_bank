defmodule BookBank.MongoAuth do
  @behaviour BookBank.Auth
  @moduledoc false

  def authenticate_user?(username, password) do
    case Mongo.find_one(:mongo, "users", %{username: username}) do
      %{username: _, password: pw} -> Argon2.verify_pass(password, pw)
      _ -> false
    end
  end

  def create_user(username, password, roles) do
    user = %{
      username: username,
      password: password,
      roles: roles
    }

    case Mongo.insert_one(:mongo, "users", user) do
      {:ok, %Mongo.InsertOneResult{acknowledged: true, inserted_id: _}} ->
        {:ok, %BookBank.User{username: username, roles: roles}}

      {:error, %{message: msg}} ->
        {:error, msg}
    end
  end

  def read_user(username) do
    case Mongo.find_one(:mongo, "users", %{username: username}) do
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

    case Mongo.update_one(:mongo, "users", %{username: username}, obj) do
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
    case Mongo.delete_many(:mongo, "users", %{username: username}) do
      {:ok, %Mongo.DeleteResult{acknowledged: true}} -> :ok
      {:ok, _} -> {:error, "The delete was not acknowledged by the server"}
      {:error, error} -> {:error, error}
    end
  end
end
