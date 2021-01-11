defmodule BookBankWeb.Utils.Auth.Token do
  use Joken.Config

  @impl true
  def token_config do
    default_claims()
    |> add_claim("sub", nil, &is_binary/1)
    |> add_claim("roles", nil, &is_list/1)
  end
end

defmodule BookBankWeb.Utils.Auth do
  alias BookBankWeb.Utils.Auth.Token, as: Token

  defp make_signer do
      Joken.Signer.create(
        "HS256",
        Application.get_env(:book_bank, BookBankWeb.Utils.Auth) |> Keyword.get(:secret)
      )
  end

  def make_token(user, roles) do
    case Token.generate_and_sign(%{"sub" => user, "roles" => roles}, make_signer()) do
      {:ok, token, _claims} -> {:ok, token}
      {:error, error} -> {:error, to_string(error)}
    end
  end

  @spec verify_token(binary) :: {:error, binary}
  def verify_token(jwt) do
    case Token.verify_and_validate(jwt, make_signer()) do
      {:ok, %{"sub" => user, "roles" => []} = claims} ->
        if BookBank.Auth.UserBlacklist.check(user) do
          {:error, "This JWT cannot be used."}
        else
          {:ok, claims}
        end
      {:error, error} -> {:error, to_string(error)}
    end
  end
end
