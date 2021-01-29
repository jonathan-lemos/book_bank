defmodule BookBank.Book do
  @moduledoc false

  use TypedStruct

  typedstruct do
    field(:id, String.t(), enforce: true)
    field(:title, String.t(), enforce: true)
    field(:size, non_neg_integer(), enforce: true)
    field(:metadata, %{String.t() => String.t()}, enforce: true)
  end
end
