defmodule BookBank.Auth.UserWhitelist do
  @behaviour BookBank.Auth.UserWhitelistBehavior

  @time_service Application.get_env(:joken, :current_time_adapter)

  def init() do
    :ets.new(:user_whitelist, [:set, :public, :named_table])
  end

  def uninit() do
    try do
      :ets.delete(:user_whitelist)
      :ok
    rescue
      _ -> :ok
    end
  end

  @moduledoc """
    Stores the list of users that are allowed to authenticate with a JWT and the time of authentication.
    An entry will live at least as long as the ttl_seconds specified in start_link/1.
  """

  @doc """
  Adds a user to the whitelist. This will overwrite an existing entry in the table.
  """
  @spec insert(String.t(), integer()) :: :ok
  def insert(user, iat) do
    :ets.insert(
      :user_whitelist,
      {user, iat, iat + BookBankWeb.Utils.Jwt.Token.token_lifetime_seconds()}
    )

    :ok
  end

  @doc """
  Returns true if a user is present in the whitelist and their token was not issued before they were last insert()'ed into the whitelist.
  """
  def check(user, iat) do
    case :ets.lookup(:user_whitelist, user) do
      [{^user, valid_beyond, valid_until}] ->
        ct = @time_service.current_time()
        cond do
          iat !== valid_beyond ->
            :ets.delete(:user_whitelist, user)
            false
          valid_beyond <= ct and ct <= valid_until ->
            true
          true ->
            :ets.delete(:user_whitelist, user)
            false
        end
      _ ->
        false
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

  def delete_expired_entries() do
    cur_time = @time_service.current_time()
    expr = :ets.fun2ms(fn {_user, _, valid_until} -> cur_time > valid_until end)
    :ets.select_delete(:user_whitelist, expr)
  end
end
