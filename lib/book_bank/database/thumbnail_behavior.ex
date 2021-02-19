defmodule BookBank.ThumbnailBehavior do
  @callback create(input :: Stream.t(), output :: collectable, max_width :: non_neg_integer(), max_height :: non_neg_integer()) ::
              {:ok, collectable} | {:error, collectable} when collectable: Collectable.t()
end
