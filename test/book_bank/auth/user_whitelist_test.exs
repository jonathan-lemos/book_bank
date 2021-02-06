defmodule BookBank.Auth.UserWhitelistTest do
  use ExUnit.Case, async: false
  import Mox
  import BookBank.Auth.UserWhitelist

  setup :verify_on_exit!

  setup do
    {:ok, _pid} = GenServer.start_link(BookBank.Auth.UserWhitelist, [ttl_seconds: 10], name: BookBank.Auth.UserWhitelist)
    Test.StubTime.set_current_time(0)
    on_exit(&uninit/0)
  end

  test "Can retrieve inserted user" do
    assert :ok = insert("user1", 0)

    assert check("user1", 0) === {:ok, true}
  end

  test "Cannot retrieve expired user" do
    assert :ok = insert("user1", 5)

    Test.StubTime.set_current_time(20)
    assert check("user1", 5) === {:ok, false}
  end

  test "Cannot retrieve deleted user" do
    assert :ok = insert("user1", 0)
    Test.StubTime.set_current_time(2)
    assert :ok = delete("user1")
    Test.StubTime.set_current_time(12)

    assert check("user1", 0) === {:ok, false}
  end

  test "Users expire" do
    assert :ok = insert("user1", 0)

    assert :ok = GenServer.call(BookBank.Auth.UserWhitelist, :rotate_cache)
    assert :ok = GenServer.call(BookBank.Auth.UserWhitelist, :rotate_cache)

    assert {:atomic, list1} = :mnesia.transaction(fn ->
      :mnesia.read({:user_whitelist_1, "user1"})
    end)

    assert {:atomic, list2} = :mnesia.transaction(fn ->
      :mnesia.read({:user_whitelist_2, "user1"})
    end)

    assert length(list1 ++ list2) === 0
  end
end
