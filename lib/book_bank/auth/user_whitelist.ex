defmodule BookBank.Auth.UserWhitelist do
  @moduledoc """
    Stores the list of users that are allowed to authenticate with a JWT and the time of authentication.
    An entry will live at least as long as the ttl_seconds specified in start_link/1.
  """

  use GenServer

  @doc """
  Adds a user to the whitelist.
  """
  @spec insert(String.t()) :: :ok
  def insert(user, iat \\ System.monotonic_time()) do
    GenServer.call(__MODULE__, {:insert, user, iat})
  end

  @doc """
  Returns true if a user is present in the whitelist and their token was not issued before they were last insert()'ed into the whitelist.
  """
  @spec check(String.t(), non_neg_integer()) :: boolean()
  def check(user, iat) do
    GenServer.call(__MODULE__, {:check, user, iat})
  end

  @doc """
  Removes a user from the whitelist if they are present.
  """
  @spec delete(String.t()) :: :ok
  def delete(user) do
    GenServer.call(__MODULE__, {:delete, user})
  end

  def start_link(ttl_seconds) do
    GenServer.start_link(__MODULE__, ttl_seconds, name: __MODULE__)
  end

  @spec init(non_neg_integer()) :: {:ok, %{ttl: any}}
  def init(ttl_seconds) when ttl_seconds >= 0 do
    :ets.new(:user_whitelist, [:set, :protected, :named_table])
    {:ok, %{ttl: ttl_seconds}}
  end

  def handle_call({:insert, user, iat}, _from, state = %{ttl: ttl}) do
    :ets.insert(:user_whitelist, {user, iat, iat + ttl})
    {:reply, :ok, state}
  end

  def handle_call({:check, user, iat}, _from, state) do
    case :ets.lookup(:user_whitelist, user) do
      [{^user, valid_beyond, valid_until}] ->
        if System.monotonic_time(:second) <= valid_until and iat >= valid_beyond do
          {:reply, true, state}
        else
          :ets.delete(:user_whitelist, user)
          {:reply, false, state}
        end
      _ -> {:reply, false, state}
    end
  end

  def handle_call({:delete, user}, _from, state) do
    :ets.delete(:user_whitelist, user)
    {:reply, :ok, state}
  end

  def handle_info(:clear_cache, state) do
    cur_time = System.monotonic_time()
    expr = :ets.fun2ms(fn {_user, _, valid_until} -> cur_time > valid_until end)
    :ets.select_delete(:user_whitelist, expr)
    schedule_clear_cache(state)
    {:noreply, state}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  defp schedule_clear_cache(%{ttl: ttl}) do
    Process.send_after(self(), :clear_cache, ttl * 1000)
  end
end
