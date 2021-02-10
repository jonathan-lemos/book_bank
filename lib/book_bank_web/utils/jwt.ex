defmodule BookBankWeb.Utils.Jwt.Token do
  use Joken.Config

  @spec token_lifetime_seconds :: pos_integer()
  def token_lifetime_seconds do
    Application.get_env(:book_bank, BookBankWeb.Utils.Jwt.Token)[:lifetime_seconds]
  end

  @impl true
  def token_config do
    default_claims(default_exp: token_lifetime_seconds())
    |> add_claim("sub", nil, &is_binary/1)
    |> add_claim("roles", nil, &is_list/1)
  end
end

defmodule BookBankWeb.Utils.Jwt do
  @behaviour BookBankWeb.Utils.JwtBehavior
  @whitelist_behavior Application.get_env(:book_bank, :services)[BookBank.Auth.UserWhitelistBehavior]
  alias BookBankWeb.Utils.Jwt.Token, as: Token

  defp make_signer do
    Joken.Signer.create(
      "HS256",
      Application.get_env(:book_bank, BookBankWeb.Utils.Jwt) |> Keyword.get(:secret)
    )
  end

  def make_token(user, roles) do
    case Token.generate_and_sign(%{"sub" => user, "roles" => roles}, make_signer()) do
      {:ok, token, %{"iat" => iat}} ->
        :ok = @whitelist_behavior.insert(user, iat)
        {:ok, token}

      {:error, error} ->
        :ok = @whitelist_behavior.delete(user)
        {:error, Kernel.inspect(error)}
    end
  end

  def verify_token(jwt) do
    case Token.verify_and_validate(jwt, make_signer()) do
      {:ok, %{"iat" => iat, "sub" => user, "roles" => roles} = claims} when is_list(roles) ->
        if @whitelist_behavior.check(user, iat) do
          {:ok, claims}
        else
          {:error, "This JWT cannot be used."}
        end

      {:ok, _} ->
        {:error, "This JWT is outdated."}

      {:error, error} ->
        {:error, Kernel.inspect(error)}
    end
  end
end
