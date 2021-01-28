defmodule BookBank.Auth.UserWhitelistTest do
  use ExUnit.Case, async: false
  import Mox
  import Test.Utils
  import BookBank.Auth.UserWhitelist

  setup :verify_on_exit!

  setup do
    init()
    Test.StubTime.set_current_time(0)
    on_exit(&uninit/0)
  end

  test "Can retrieve inserted user" do
    insert("user1", 0)

    assert check("user1", 0) === true
  end

  test "Cannot retrieve expired user" do
    expect_lifetime(3)
    insert("user1", 5)

    Test.StubTime.set_current_time(9)
    assert check("user1", 5) === false
  end

  test "Cannot retrieve deleted user" do
    expect_lifetime(5)
    insert("user1", 0)

    Test.StubTime.set_current_time(2)
    delete("user1")
    Test.StubTime.set_current_time(3)

    assert check("user1", 0) === false
  end

  test "Users expire" do
    expect_lifetime(5)
    insert("user1", 0)

    Test.StubTime.set_current_time(10)
    delete_expired_entries()

    assert check("user1", 0) === false
  end
end
