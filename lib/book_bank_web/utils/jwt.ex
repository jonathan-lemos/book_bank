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

  import BookBank.DI, only: [whitelist_service: 0]

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
        :ok = whitelist_service().insert(user, iat)
        {:ok, token}

      {:error, error} ->
        :ok = whitelist_service().delete(user)
        {:error, Kernel.inspect(error)}
    end
  end

  def verify_token(jwt) do
    case Token.verify_and_validate(jwt, make_signer()) do
      {:ok, %{"iat" => iat, "sub" => user, "roles" => roles} = claims} when is_list(roles) ->
        if whitelist_service().check(user, iat) do
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
