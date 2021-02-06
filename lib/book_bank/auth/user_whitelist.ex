defmodule BookBank.Auth.UserWhitelist do
  @behaviour BookBank.Auth.UserWhitelistBehavior
  @time_service Application.get_env(:joken, :current_time_adapter)

  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(list) do
    ttl = list[:ttl_seconds]
    :mnesia.create_schema([])
    :mnesia.create_table(:user_whitelist_1, attributes: [:username, :valid_beyond, :valid_until])
    :mnesia.create_table(:user_whitelist_2, attributes: [:username, :valid_beyond, :valid_until])
    :mnesia.wait_for_tables([:user_whitelist_1, :user_whitelist_2], 10000)
    Process.send_after(__MODULE__, :rotate_cache, ttl * 1000)
    {:ok, %{current: :user_whitelist_1, ttl_seconds: ttl, first_rotate: true}}
  end

  def uninit() do
    try do
      :mnesia.delete_table(:user_whitelist_1)
      :mnesia.delete_table(:user_whitelist_2)
      :ok
    rescue
      _ -> :ok
    end
  end

  defp current_table() do
    GenServer.call(__MODULE__, :current_table)
  end

  defp get_ttl() do
    GenServer.call(__MODULE__, :get_ttl)
  end

  def rotate_cache(%{current: current, ttl_seconds: _ttl_seconds, first_rotate: fr} = state) do
    next =
      if current === :user_whitelist_1 do
        :user_whitelist_2
      else
        :user_whitelist_1
      end

    state = state |> Map.merge(%{current: next, first_rotate: false})

    if fr do
      {state, :ok}
    else
      {state, :mnesia.clear_table(next) |> transaction_result()}
    end
  end

  @impl true
  def handle_call(:current_table, _from, %{current: table} = state) do
    {:reply, table, state}
  end

  @impl true
  def handle_call(:get_ttl, _from, %{ttl_seconds: ttl_seconds} = state) do
    {:reply, ttl_seconds, state}
  end

  @impl true
  def handle_call(:rotate_cache, _from, state) do
    {state, clear_result} = rotate_cache(state)
    {:reply, clear_result, state}
  end

  @impl true
  def handle_info(:rotate_cache, %{ttl_seconds: ttl_seconds} = state) do
    {state, _clear_result} = rotate_cache(state)
    Process.send_after(__MODULE__, :rotate_cache, ttl_seconds * 1000)
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp transaction_result(res) do
    case res do
      {:atomic, :ok} -> :ok
      {:atomic, e} -> {:ok, e}
      {:aborted, e} when is_binary(e) -> {:error, e}
      {:aborted, e} -> {:error, Kernel.inspect(e)}
    end
  end

  @moduledoc """
    Stores the list of users that are allowed to authenticate with a JWT and the time of authentication.
    An entry will live at least as long as the ttl_seconds specified in start_link/1.
  """

  @doc """
  Adds a user to the whitelist. This will overwrite an existing entry in the table.
  """
  @impl true
  def insert(user, iat) do
    :mnesia.transaction(fn ->
      :mnesia.write({current_table(), user, iat, iat + get_ttl()})
    end)
    |> transaction_result()
  end

  defp check_read(table, user, iat) do
    case :mnesia.transaction(fn -> :mnesia.read({table, user}) end) |> transaction_result() do
      {:ok, [{^table, ^user, valid_beyond, valid_until}]} ->
        ct = @time_service.current_time()

        cond do
          iat !== valid_beyond ->
            __MODULE__.delete(user)
            :invalid

          valid_beyond <= ct and ct <= valid_until ->
            :valid

          true ->
            __MODULE__.delete(user)
            :invalid
        end

      {:ok, []} ->
        nil

      {:error, e} ->
        {:error, e}
    end
  end

  @doc """
  Returns true if a user is present in the whitelist and their token was not issued before they were last insert()'ed into the whitelist.
  """
  @impl true
  def check(user, iat) do
    current = current_table()

    {first, second} =
      if current === :user_whitelist_1 do
        {:user_whitelist_1, :user_whitelist_2}
      else
        {:user_whitelist_2, :user_whitelist_1}
      end

    case check_read(first, user, iat) || check_read(second, user, iat) do
      :valid -> {:ok, true}
      :invalid -> {:ok, false}
      nil -> {:ok, false}
      {:error, e} -> {:error, e}
    end
  end

  @doc """
  Removes a user from the whitelist if they are present.
  """
  @impl true
  def delete(user) do
    :mnesia.transaction(fn ->
      :mnesia.delete({:user_whitelist_2, user})
      :mnesia.delete({:user_whitelist_1, user})
    end)
    |> transaction_result()
  end
end
