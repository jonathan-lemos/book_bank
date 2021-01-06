defmodule BookBank.Book do
  @moduledoc false

  use TypedStruct

  typedstruct do
    field :id, String.t, enforce: true
    field :title, String.t, enforce: true
    field :body, Enumerable.t, enforce: true
    field :metadata, %{string => string}, enforce: true
  end
end
