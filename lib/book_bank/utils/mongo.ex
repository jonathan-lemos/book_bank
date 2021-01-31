defmodule BookBank.Utils.Mongo do
  @doc """
  A write concern ensuring that at a majority of the nodes have acknowledged the write.
  """
  def write_concern_majority(timeout_ms \\ 10000) when timeout_ms >= 0 do
    %{w: "majority", j: true, wtimeout: timeout_ms}
  end

  @doc """
  A write concern ensuring that at least two nodes have acknowledged the write.
  """
  def write_concern_2(timeout_ms \\ 2500) when timeout_ms >= 0 do
    %{w: 2, j: true, wtimeout: timeout_ms}
  end

  @doc """
  A write concern ensuring that at least three nodes have acknowledged the write.
  """
  def write_concern_3(timeout_ms \\ 2500) when timeout_ms >= 0 do
    %{w: 3, j: true, wtimeout: timeout_ms}
  end

  def is_kvpmap(map) do
    is_map(map) and Enum.all?(fn e -> match?({k, v} when is_binary(k) and is_binary(v), e) end)
  end

  def is_kvplist(list) do
    is_list(list) and
      Enum.all?(fn e ->
        match?(%{"key" => k, "value" => v} when is_binary(k) and is_binary(v), e)
      end)
  end

  def kvpmap_to_kvplist(map) do
    if is_kvpmap(map) do
      {:ok, map |> Enum.map(fn {k, v} -> %{"key" => k, "value" => v} end)}
    else
      :error
    end
  end

  def kvpmap_to_kvplist!(map) do
    case kvplist_to_kvpmap(map) do
      {:ok, list} -> list
      :error -> raise ArgumentError, message: "The argument was not a %{String.t() => String.t()}"
    end
  end

  def kvplist_to_kvpmap(list) do
    if is_kvplist(list) do
      {:ok, list |> Map.new(fn %{"key" => k, "value" => v} -> {k, v} end)}
    else
      :error
    end
  end

  def kvplist_to_kvpmap!(list) do
    case kvplist_to_kvpmap(list) do
      {:ok, map} -> map
      :error -> raise ArgumentError, message: "The argument was not a key-value-pair list."
    end
  end

  defp object_merge_list([head | tail], accumulator_list, accumulator_existing) do
    if accumulator_existing |> MapSet.member?(head) do
      object_merge_list(tail, accumulator_list, accumulator_existing)
    else
      object_merge_list(tail, [head | accumulator_list], accumulator_existing |> MapSet.put(head))
    end
  end

  defp object_merge_list([], acc, _existing) do
    acc
  end

  defp object_merge_lists(a, b) do
    object_merge_list(b, a |> Enum.reverse(), a |> MapSet.new) |> Enum.reverse()
  end

  defp object_merge_map([{key, value} | tail], acc) do
    if acc |> Map.has_key?(key) do
      object_merge_map(tail, Map.put(acc, key, object_merge(acc |> Map.get(key), value)))
    else
      object_merge_map(tail, Map.put(acc, key, value))
    end
  end

  defp object_merge_map([], acc) do
    acc
  end

  defp object_merge_maps(a, b) do
    object_merge_map(b |> Enum.map(&(&1)), a)
  end

  def object_merge(a, b) do
    cond do
      is_map(a) and is_map(b) -> object_merge_maps(a, b)
      is_list(a) and is_list(b) -> object_merge_lists(a, b)
      true -> b
    end
  end
end
