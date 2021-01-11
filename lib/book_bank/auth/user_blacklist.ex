defmodule BookBank.Auth.UserBlacklist do
  @moduledoc """
    Stores the list of users that are not allowed to authenticate with a JWT.
    An entry will live at least as long as the ttl_seconds specified in start_link/1.
  """

  use GenServer

  @spec insert(String.t()) :: :ok
  def insert(user) do
    GenServer.call(__MODULE__, {:insert, user})
  end

  @spec check(String.t()) :: boolean()
  def check(user) do
    GenServer.call(__MODULE__, {:check, user})
  end

  @spec delete(String.t()) :: :ok
  def delete(user) do
    GenServer.call(__MODULE__, {:delete, user})
  end

  def start_link(ttl_seconds) do
    GenServer.start_link(__MODULE__, ttl_seconds, name: __MODULE__)
  end

  @spec init(non_neg_integer()) :: {:ok, %{ttl: any}}
  def init(ttl_seconds) when ttl_seconds >= 0 do
    :ets.new(:user_blacklist, [:set, :protected, :named_table])
    {:ok, %{ttl: ttl_seconds}}
  end

  def handle_call({:insert, user}, _from, state = %{ttl: ttl}) do
    :ets.insert(:user_blacklist, {user, System.monotonic_time(:second) + ttl})
    {:reply, :ok, state}
  end

  def handle_call({:check, user}, _from, state) do
    case :ets.lookup(:user_blacklist, user) do
      [{^user, ttl_stored}] ->
        if System.monotonic_time(:second) <= ttl_stored do
          {:reply, true, state}
        else
          :ets.delete(:user_blacklist, user)
          {:reply, false, state}
        end
      _ -> {:reply, false, state}
    end
  end

  def handle_call({:delete, user}, _from, state) do
    :ets.delete(:user_blacklist, user)
    {:reply, :ok, state}
  end

  def handle_info(:clear_cache, state) do
    tm = System.monotonic_time()
    expr = :ets.fun2ms(fn {_user, time} -> time > tm end)
    :ets.select_delete(:user_blacklist, expr)
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
