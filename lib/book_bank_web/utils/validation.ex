defmodule BookBankWeb.Validation do
  def validate_integer(value, upper: ub, lower: lb) when is_integer(value) do
    validate_integer(value, lower: lb, upper: ub)
  end

  def validate_integer(value, lower: lb, upper: ub) when is_integer(value) do
    if lb <= value and value <= ub do
      {:ok, value}
    else
      {:error, "#{value} is not in the range #{lb} to #{ub}, was #{value}."}
    end
  end

  def validate_integer(value, lower: lb) when is_integer(value) do
    if lb <= value do
      {:ok, value}
    else
      {:error, "#{value} must be at least #{lb}, was #{value}."}
    end
  end

  def validate_integer(value, upper: ub) when is_integer(value) do
    if value <= ub do
      {:ok, value}
    else
      {:error, "#{value} must be at most #{ub}, was #{value}."}
    end
  end

  def validate_integer(value, []) when is_integer(value) do
    {:ok, value}
  end

  def validate_integer(value, range) when is_binary(value) and is_list(range) do
    case Integer.parse(value) do
      {num, ""} -> validate_integer(num, range)
      {_num, _extra} -> {:error, "#{value} is not an integer."}
      :error -> {:error, "#{value} is not an integer."}
    end
  end

  defp validate_map(value, []) when is_map(value) do
    true
  end

  defp validate_map(value, [{map_key, map_value} | tail]) when is_map(value) do
    if validate_schema(Map.get(value, map_key), map_value) do
      validate_map(value, tail)
    else
      false
    end
  end

  defp validate_map(_value, _map) do
    false
  end

  defp validate_list([], []) do
    true
  end

  defp validate_list([vhead | vtail], [shead | stail]) do
    if validate_schema(vhead, shead) do
      validate_list(vtail, stail)
    else
      false
    end
  end

  defp validate_list(_value, _) do
    false
  end

  def validate_schema(value, schema) do
    case schema do
      :string -> is_binary(value)
      :integer -> is_integer(value)
      s when is_map(s) -> validate_map(value, Map.to_list(s))
      l when is_list(l) -> validate_list(value, l)
      {:list, subschema} -> is_list(value) and Enum.all?(value, fn v -> validate_schema(v, subschema) end)
      _ -> value === schema
    end
  end

end
