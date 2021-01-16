defmodule BookBank.Database do
  @moduledoc false
  @callback create_book(
              title :: String.t(),
              body :: Stream.t(),
              metadata :: %{String.t() => String.t()}
            ) ::
              {:ok, BookBank.Book} | {:error, String.t()}
  @callback read_book(id :: String.t()) ::
              {:ok, BookBank.Book} | {:error, :does_not_exist | String.t()}
  @callback update_book(
              id :: String.t(),
              update ::
                list(
                  {:replace_metadata,
                   %{String.t() => String.t()}
                   | {:remove, String.t()}
                   | {:update, String.t(), String.t()}}
                )
            ) :: :ok | {:error, :does_not_exist | String.t()}
  @callback delete_book(id :: String.t()) :: :ok | {:error, :does_not_exist | String.t()}
end
