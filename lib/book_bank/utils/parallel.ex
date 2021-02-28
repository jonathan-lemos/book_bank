defmodule BookBank.Utils.Parallel do
  @spec invoke(list((() -> ret_type))) :: [ret_type] when ret_type: var
  def invoke(e) do
    Enum.map(e, &Task.async/1) |> Enum.map(&Task.await(&1, 60_000))
  end
end
