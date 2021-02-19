defmodule BookBank.ImageMagickThumbnail do
  @behaviour BookBank.ThumbnailBehavior

  def create(input, output, max_width, max_height)
      when is_integer(max_width) and is_integer(max_height) do
    case Porcelain.exec(
           "convert",
           ["-resize", "#{max_width}x#{max_height}>", "pdf:-[0]", "jpeg:-"],
           in: input,
           out: output,
           err: :out
         ) do
      %Porcelain.Result{status: 0, out: collectable} -> {:ok, collectable}
      %Porcelain.Result{out: collectable} -> {:error, collectable}
    end
  end
end
