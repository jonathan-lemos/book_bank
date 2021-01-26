defmodule BookBankWeb.Utils.JwtTime do
  @behaviour Joken.CurrentTime

  def current_time() do
    System.monotonic_time(:second)
  end
end
