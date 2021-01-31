defmodule BookBank.MongoAuth do
  @behaviour BookBank.AuthBehavior

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

  def update_user(username, updates) do
    set = if updates[:password] !== nil do
      true = updates[:password] |> is_binary()
      %{"$set" => %{"password" => updates[:password]}}
    else
      %{}
    end

    push = if updates[:add_roles] !== nil do
      ar = updates[:add_roles]
      true = ar |> Enum.all?(&is_binary/1)
      %{"$addToSet" => %{"$each" => %{"roles" => ar}}}
    else
      %{}
    end

    pull = if updates[:remove_roles] !== nil do
      rr = updates[:remove_roles] |> Enum.filter(&(&1 not in push))
      true = rr |> Enum.all?(&is_binary/1)
      %{"$pullAll" => %{"roles" => rr}}
    else
      %{}
    end

    obj = Enum.reduce([set, push, pull], &BookBank.Utils.Mongo.object_merge/2)

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
