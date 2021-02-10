defmodule BookBank.ThumbnailBehavior do
  @callback create(input: Stream.t(), width: non_neg_integer(), height: non_neg_integer()) :: {:ok, Stream.t()} | {:error, String.t()}
end
