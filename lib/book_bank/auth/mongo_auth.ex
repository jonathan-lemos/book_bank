defmodule BookBank.MongoAuth do
  @behaviour BookBank.Auth
  @moduledoc false

  use GenServer

  def init(_) do
    # the server doesn't need any state, so we use nil
    {:ok, nil}
  end

  @spec authenticate_user?(String.t(), String.t()) :: boolean
  def authenticate_user?(username, password) do
    GenServer.call(__MODULE__, {:auth, username, password})
  end

  @spec create_user(String.t(), String.t(), list(String.t())) ::
          {:ok, BookBank.User}
          | {
              :error,
              :user_exists | String.t()
            }
  def create_user(username, password, roles) do
    GenServer.call(__MODULE__, {:create, {username, password, roles}})
  end

  @spec read_user(String.t()) :: {:ok, BookBank.User} | {:error, :does_not_exist | String.t()}
  def read_user(username) do
    GenServer.call(__MODULE__, {:read, username})
  end

  @spec update_user(
          String.t(),
          list({:password, String.t()} | {:add_role, String.t()} | {:remove_role, String.t()})
        ) :: :ok | {:error, :does_not_exist | String.t()}
  def update_user(username, updates) do
    GenServer.call(__MODULE__, {:update, username, updates})
  end

  @spec delete_user(username :: String.t()) :: :ok | {:error, :does_not_exist | String.t()}
  def delete_user(username) do
    GenServer.call(__MODULE__, {:delete, username})
  end

  def handle_call({:auth, username, password}, _from, state) do
    b =
      case Mongo.find_one(:mongo, "users", %{username: username}) do
        %{username: _, password: pw} -> Argon2.verify_pass(password, pw)
        _ -> false
      end

    {:reply, b, state}
  end

  def handle_call({:create, {username, password, roles}}, _from, state) do
    user = %{
      username: username,
      password: password,
      roles: roles
    }

    case Mongo.insert_one(:mongo, "users", user) do
      {:ok, %Mongo.InsertOneResult{acknowledged: true, inserted_id: _}} ->
        {:reply, {:ok, %BookBank.User{username: username, roles: roles}}, state}

      {:error, error} ->
        {:reply, {:error, error}}
    end
  end

  def handle_call({:read, username}, _from, state) do
    case Mongo.find_one(:mongo, "users", %{username: username}) do
      %{username: un, password: _, roles: r} ->
        {:reply, {:ok, %BookBank.User{username: un, roles: r}}, state}

      nil ->
        {:reply, {:error, :does_not_exist}}
    end
  end

  @spec handle_call(
          {:update, String.t(),
           list({:password, String.t()} | {:add_role, String.t()} | {:remove_role, String.t()})},
          term,
          term
        ) :: {:reply, term, term}
  def handle_call({:update, username, updates}, _from, state) do
    groups =
      updates
      |> Enum.group_by(fn x -> elem(x, 0) end)

    obj = %{}

    obj =
      case groups do
        %{password: [pw | _]} -> obj |> Map.put("$set", %{password: pw})
        _ -> obj
      end

    obj =
      case groups do
        %{remove_roles: roles} -> obj |> Map.put("$pullAll", %{"roles" => roles})
        _ -> obj
      end

    obj =
      case groups do
        %{update_role: roles} -> obj |> Map.put("$addToSet", %{"roles" => roles})
        _ -> obj
      end

    case Mongo.update_one(:mongo, "users", %{username: username}, obj) do
      {:ok, %Mongo.UpdateResult{acknowledged: true, matched_count: n}} ->
        if n > 0 do
          {:reply, :ok, state}
        else
          {:reply, {:error, :does_not_exist}, state}
        end

      {:ok, %Mongo.UpdateResult{acknowledged: false}} ->
        {:reply, {:error, "The update request was not acknowledged."}, state}

      {:error, error} ->
        {:reply, {:error, error}, state}
    end
  end

  def handle_call({:delete, username}, _from, state) do
    r =
      case Mongo.delete_many(:mongo, "users", %{username: username}) do
        {:ok, %Mongo.DeleteResult{acknowledged: true}} -> :ok
        {:ok, _} -> {:error, "The delete was not acknowledged by the server"}
        {:error, error} -> {:error, error}
      end

    {:reply, r, state}
  end
end
