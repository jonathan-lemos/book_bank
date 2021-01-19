defmodule BookBank.Utils.Parallel do
  @spec invoke(list((() -> any))) :: [any]
  def invoke(e) do
    Enum.map(e, &Task.start/1) |> Enum.map(&Task.await/1)
  end
end
