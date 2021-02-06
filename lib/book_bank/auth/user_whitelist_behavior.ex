defmodule BookBank.Auth.UserWhitelistBehavior do
  @callback insert(username :: String.t(), iat :: integer()) :: :ok | {:error, String.t()}
  @callback check(username :: String.t(), iat :: integer()) :: {:ok, boolean()} | {:error, String.t()}
  @callback delete(username :: String.t()) :: :ok | {:error, String.t()}
end
