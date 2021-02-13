defmodule BookBank.DatabaseBehavior do
  @moduledoc false
  @callback create_book(
              title :: String.t(),
              body :: Stream.t(),
              metadata :: %{String.t() => String.t()}
            ) ::
              {:ok, BookBank.Book} | {:error, String.t()}
  @callback get_book_metadata(id :: String.t()) ::
              {:ok, BookBank.Book} | {:error, :does_not_exist | String.t()}
  @callback get_book_file(id :: String.t()) :: {:ok, Stream.t(), BookBank.Book} | {:error, :does_not_exist | String.t()}
  @callback get_book_thumb(id :: String.t()) :: {:ok, Stream.t(), BookBank.Book} | {:error, :does_not_exist | String.t()}
  @callback get_book_cover(id :: String.t()) :: {:ok, Stream.t(), BookBank.Book} | {:error, :does_not_exist | String.t()}
  @callback update_book(
              id :: String.t(),
              update ::
                list(
                  {:set_metadata,
                   %{String.t() => String.t()}}
                   | {:remove_metadata, list(String.t())}
                   | {:add_metadata, %{String.t() => String.t()}}
                   | {:set_title, String.t()}
                )
            ) :: :ok | {:error, :does_not_exist | String.t()}
  @callback delete_book(id :: String.t()) :: :ok | {:error, :does_not_exist | String.t()}
end
