defmodule BookBankWeb.Utils.JwtBehavior do
  @callback make_token(user :: String.t(), roles :: list(String.t())) ::
              {:ok, String.t()} | {:error, String.t()}
  @callback verify_token(jwt :: String.t()) ::
              {:ok, %{String.t() => String.t()}} | {:error, String.t()}
end
