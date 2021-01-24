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
end
