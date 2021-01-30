defmodule BookBank.AuthBehavior do
  @moduledoc false
  @callback authenticate_user(username :: String.t(), password :: String.t()) :: {:ok, BookBank.User.t()} | {:error, :does_not_exist | :wrong_password}

  @callback create_user(username :: String.t(), password :: String.t(), roles :: list(String.t())) ::
              {:ok, BookBank.User.t()} | {:error, :user_exists | String.t()}
  @callback get_user(username :: String.t()) ::
              {:ok, BookBank.User.t()} | {:error, :does_not_exist | String.t()}
  @callback update_user(
              username :: String.t(),
              update ::
                list(
                  {:password, String.t()}
                  | {:add_roles, list(String.t())}
                  | {:remove_roles, list(String.t())}
                  | {:set_roles, list(String.t())}
                )
            ) :: :ok | {:error, :does_not_exist | String.t()}
  @callback delete_user(username :: String.t()) :: :ok | {:error, :does_not_exist | String.t()}
  @callback users_with_role(role :: String.t()) :: {:ok, list(BookBank.User.t())} | {:error, String.t()}

  def roles() do
    ["admin", "librarian"]
  end
end
