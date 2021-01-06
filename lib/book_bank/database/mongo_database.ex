
defmodule BookBank.MongoDatabase do
  use GenServer

  def init(_) do
    # the server doesn't need any state, so we use nil
    {:ok, nil}
  end

  def handle_call({:create, })
end
