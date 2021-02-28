defmodule BookBank.Utils.Set do
  @spec minus(enumerable :: list(type), without :: list(type)) :: list(type) when type: var
  def minus(enumerable, without) do
    ms = without |> MapSet.new()

    enumerable |> Enum.filter(&(not MapSet.member?(ms, &1)))
  end

  def union(enumerable, add) do
    existing = enumerable |> MapSet.new()

    enumerable ++ (add |> Enum.filter(&(not MapSet.member?(existing, &1))))
  end
end
