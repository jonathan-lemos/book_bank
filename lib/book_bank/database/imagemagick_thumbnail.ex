defmodule BookBank.ImageMagickThumbnail do
  @behaviour BookBank.ThumbnailBehavior

  def create(input, output, max_width, max_height)
      when is_integer(max_width) and is_integer(max_height) do
    file_in = Briefly.create!()
    input |> Stream.into(File.stream!(file_in)) |> Stream.run()

    case System.cmd(
      "convert",
      [
        "-resize",
        "#{max_width}x#{max_height}>",
        "pdf:#{file_in}[0]",
        "jpeg:-"
      ],
      into: output,
      stderr_to_stdout: true,
      parallelism: true
    ) do
      {coll, 0} -> {:ok, coll}
      {coll, _} -> {:error, coll}
    end
  end
end
