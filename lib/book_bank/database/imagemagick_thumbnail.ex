defmodule BookBank.ImageMagickThumbnail do
  @behaviour BookBank.ThumbnailBehavior

  def create(input, max_width, max_height) when is_integer(max_width) and is_integer(max_height) do
    file_in = Briefly.create!()
    file_out = Briefly.create!()

    input |> Stream.into(File.stream!(file_in, [], 4096))

    case System.cmd(
           "convert",
           ["-resize", "#{max_width}x#{max_height}>", "#{file_in}[0]", "#{file_out}"],
           stderr_to_stdout: true
         ) do
      {_, 0} -> {:ok, File.stream!(file_out, [], 4096)}
      {reason, _} -> {:error, reason}
    end
  end
end
