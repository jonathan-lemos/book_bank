defmodule BookBank.User do
  @moduledoc false

  use TypedStruct

  typedstruct do
    field(:username, String.t(), enforce: true)
    field(:roles, list(String.t()), enforce: true)
  end
end
