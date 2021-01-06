defmodule BookBank.MongoAuth do
  @moduledoc false

  use GenServer

  def init(_) do
    {:ok, nil}
  end

  @spec authenticate_user?(atom, String.t, String.t) :: boolean
  def authenticate_user?(pid, username, password) do
    GenServer.call(pid, {:auth, username})
  end

  def create_user(pid :: atom, username :: String.t, password :: String.t, roles :: list(String.t)) :: {:ok, User} | {:error, :user_exists | String.t} do
    GenServer.call(pid, {:create, {username, password, roles}})
  end


  def handle_call({:auth, username :: String.t}, _from, state) do
    b = case Mongo.find_one(:mongo, "users", %{username: username}) do
      %{username: username, password: pw} -> Argon2.verify_pass(password, pw)
      _ -> false
    end
    {:reply, b, state}
  end

  def handle_call({:create, {username :: String.t, password :: String.t, roles :: list(String.t)}}, _from, state) do
    user = %{
      username: username,
      password: password,
      roles: roles
    }
    case Mongo.insert_one(:mongo, "users", user) do
      {:ok, %Mongo.InsertOneResult{acknowledged: true, inserted_id: id}} ->
        {:reply, {:ok, %User{username: username, roles: roles}}, state}
      {:error, error} ->
        {:reply, {:error, error}}
    end
  end

  def handle_call({:read, username :: String.t}, _from, state) do
    case Mongo.find_one(:mongo, "users", %{username: username}) do
      {:ok, %{username: un, password: _, roles: r}} ->
        {:reply, {:ok, %User{username: un, roles: r}}, state}
      {:ok, _} ->
        {:reply, {:error, "shit's fucked"}}
      {:error, error} ->
        {:reply, {:error, error}}
    end
  end

  def handle_call(
        {
          :update,
          username :: String.t,
          updates :: list({:password, String.t} | {:add_role, String.t} | {:remove_role, String.t})
        },
        from,
        state
      ) do
    groups = update
             |> Enum.group_by(
                  &(
                    &1
                    |> elem 0)
                )

    obj = %{}

    if %{password: pw} = groups do
      obj = obj
            |> Map.put("$set", %{"password": pw})
    end

    if %{remove_roles: roles} = groups do
      obj = obj
            |> Map.put("$pullAll", Map.put("roles", roles))
    end

    if %{update_role: roles} = groups do
      obj = obj
            |> Map.put("$addToSet", Map.put("roles", roles))
    end

    Mongo.update_one(:mongo, "users", %{"username": username}, obj)

    {:reply, :ok, state}
  end

  def handle_call({:delete, username :: String.t}) do

  end

end
