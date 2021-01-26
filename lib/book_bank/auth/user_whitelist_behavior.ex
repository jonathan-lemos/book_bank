defmodule BookBank.Auth.UserWhitelistBehavior do
  @callback insert(username :: String.t(), iat :: integer()) :: :ok
  @callback check(username :: String.t(), iat :: integer()) :: boolean()
  @callback delete(username :: String.t()) :: :ok
end
