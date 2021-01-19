defmodule BookBank.Book do
  @moduledoc false

  use TypedStruct

  typedstruct do
    field(:id, String.t(), enforce: true)
    field(:title, String.t(), enforce: true)
    field(:metadata, %{String.t() => String.t()}, enforce: true)
    field(:body_id, String.t(), enforce: true)
    field(:cover_id, String.t() | nil, enforce: true)
    field(:thumb_id, String.t() | nil, enforce: true)
  end
end
