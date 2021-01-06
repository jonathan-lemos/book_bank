defmodule BookBank.Database do
  @type Book :: {:book, %{id => String.t, title => String.t, body => Enumerable.t, metadata: %{string => string}}}

  @moduledoc false
  @callback create_book(title :: String.t, body :: Enumerable.t) :: {:ok, book} | {:error, String.t}
  @callback read_book(id :: String.t) :: {:ok, book} | {:error, :does_not_exist | String.t}
  @callback update_book(id :: String.t, update :: list({:body, Enumerable.t} | {:replace_metadata, %{string => string} | {:remove, String.t} | {:update, String.t, String.t}})) :: :ok | {:error, :does_not_exist | String.t}
  @callback delete_book(id :: String.t) :: :ok | {:error, :does_not_exist | String.t}
end
