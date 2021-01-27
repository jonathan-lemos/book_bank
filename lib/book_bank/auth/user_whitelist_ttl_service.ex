defmodule BookBank.Auth.UserWhitelistTTLService do
  use Task, restart: :permanent

  @spec start_link(non_neg_integer()) :: {:ok, pid}
  def start_link(after_seconds \\ 30 * 60) do
    Task.start_link(__MODULE__, :delete_expired_after, [after_seconds])
  end

  @spec delete_expired_after(non_neg_integer) :: :ok
  def delete_expired_after(after_seconds) do
    Process.sleep(after_seconds * 1000)
    BookBank.Auth.UserWhitelist.delete_expired_entries()
    :ok
  end
end
