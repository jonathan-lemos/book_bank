defmodule BookBank.Database do
  @moduledoc false
  @callback create_book(pid :: atom, title :: String.t, body :: Enumerable.t) :: {:ok, BookBank.Book} | {:error, String.t}
  @callback read_book(pid :: atom, id :: String.t) :: {:ok, BookBank.Book} | {:error, :does_not_exist | String.t}
  @callback update_book(pid :: atom, id :: String.t, update :: list({:body, Enumerable.t} | {:replace_metadata, %{string => string} | {:remove, String.t} | {:update, String.t, String.t}})) :: :ok | {:error, :does_not_exist | String.t}
  @callback delete_book(pid :: atom, id :: String.t) :: :ok | {:error, :does_not_exist | String.t}
end
