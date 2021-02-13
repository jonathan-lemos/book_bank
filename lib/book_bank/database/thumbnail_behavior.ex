defmodule BookBank.ThumbnailBehavior do
  @callback create(input :: Stream.t(), max_width :: non_neg_integer(), max_height :: non_neg_integer()) ::
              {:ok, Stream.t()} | {:error, String.t()}
end
