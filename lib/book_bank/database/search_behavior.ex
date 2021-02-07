defmodule BookBank.SearchBehavior do
  @moduledoc false
  @callback insert_book(book :: BookBank.Book.t()) :: :ok | {:error, String.t()}
  @callback update_book(new_book :: BookBank.Book.t()) :: :ok | {:error, String.t()}
  @callback search(query :: String.t(), count :: pos_integer(), page :: non_neg_integer()) ::
              {:ok,
               list(%{
                 id: String.t(),
                 title: String.t(),
                 metadata: %{String.t() => String.t()}
               })}
              | {:error, String.t()}
  @callback search_count(query :: String.t()) :: {:ok, non_neg_integer()} | {:error, String.t()}
end
