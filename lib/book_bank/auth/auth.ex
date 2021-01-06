defmodule BookBank.Auth do
  @moduledoc false
  @callback authenticate_user?(username :: String.t, password :: String.t) :: boolean

  @callback create_user(username :: String.t, password :: String.t) :: :ok | {:error, :user_exists | String.t}
  @callback read_user(username :: String.t) :: {:ok, User} | {:error, :does_not_exist | String.t}
  @callback update_user(username :: String.t, update :: list({:password, String.t} | {:add_role, String.t} | {:remove_role, String.t})) :: :ok | {:error, :does_not_exist | String.t}
  @callback delete_user(username :: String.t) :: :ok | {:error, :does_not_exist | String.t}
end
