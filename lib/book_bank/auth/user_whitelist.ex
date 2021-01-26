defmodule BookBank.Auth.UserWhitelist do
  @behaviour BookBank.Auth.UserWhitelistBehavior

  @moduledoc """
    Stores the list of users that are allowed to authenticate with a JWT and the time of authentication.
    An entry will live at least as long as the ttl_seconds specified in start_link/1.
  """

  @doc """
  Adds a user to the whitelist. This will overwrite an existing entry in the table.
  """
  @spec insert(String.t(), integer()) :: :ok
  def insert(user, iat) do
    :ets.insert(:user_whitelist, {user, iat, iat + BookBankWeb.Utils.Jwt.Token.token_lifetime_seconds()})
    :ok
  end

  @doc """
  Returns true if a user is present in the whitelist and their token was not issued before they were last insert()'ed into the whitelist.
  """
  def check(user, iat) do
    case :ets.lookup(:user_whitelist, user) do
      [{^user, valid_beyond, valid_until}] ->
        if System.monotonic_time(:second) <= valid_until and iat >= valid_beyond do
          true
        else
          :ets.delete(:user_whitelist, user)
          false
        end
      _ -> false
    end
  end

  @doc """
  Removes a user from the whitelist if they are present.
  """
  @spec delete(String.t()) :: :ok
  def delete(user) do
    :ets.delete(:user_whitelist, user)
    :ok
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
