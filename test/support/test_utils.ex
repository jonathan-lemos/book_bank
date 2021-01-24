defmodule Test.Utils do
  def json_response(conn) do
    response = :erlang.iolist_to_binary(conn.resp_body)
    Jason.decode(response)
  end
end
