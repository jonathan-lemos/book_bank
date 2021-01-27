defmodule BookBankWeb.Utils.JwtTest do
  use ExUnit.Case, async: false
  import Mox
  import BookBankWeb.Utils.Jwt
  import Test.Utils

  setup :verify_on_exit!

  setup do
    Test.StubTime.set_current_time(0)
  end

  test "JWT can be verified" do
    expect(BookBank.Auth.MockUserWhitelist, :insert, fn "user", 0 -> :ok end)
    expect(BookBank.Auth.MockUserWhitelist, :check, fn "user", 0 -> :ok end)
    expect_lifetime(5)

    assert {:ok, jwt} = make_token("user", ["admin"])
    Test.StubTime.set_current_time(1)
    assert {:ok, %{"sub" => "user", "roles" => ["admin"]}} = verify_token(jwt)
  end

  test "JWT can be verified in last second" do
    expect(BookBank.Auth.MockUserWhitelist, :insert, fn "user", 3 -> :ok end)
    expect(BookBank.Auth.MockUserWhitelist, :check, fn "user", 3 -> :ok end)
    expect_lifetime(5)

    Test.StubTime.set_current_time(3)
    assert {:ok, jwt} = make_token("user", ["admin"])
    Test.StubTime.set_current_time(5)
    assert {:ok, %{"sub" => "user", "roles" => ["admin"]}} = verify_token(jwt)
  end

  test "Expired JWT cannot be verified" do
    expect(BookBank.Auth.MockUserWhitelist, :insert, fn "user", 3 -> :ok end)
    expect_lifetime(5)

    Test.StubTime.set_current_time(3)
    assert {:ok, jwt} = make_token("user", ["admin"])
    Test.StubTime.set_current_time(10)
    assert {:error, _} = verify_token(jwt)
  end

  test "Invalid JWT cannot be verified" do
    # good_jwt =
    # "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJKb2tlbiIsImV4cCI6OCwiaWF0IjozLCJpc3MiOiJKb2tlbiIsImp0aSI6IjJwZXR1bDhhMTY0cmRrcmR1MDAwMDFxMSIsIm5iZiI6Mywicm9sZXMiOlsiYWRtaW4iXSwic3ViIjoidXNlciJ9.mVww76Y5gdA0RfTyod9sjbq9nzBpV4refMhE-CiyDGU" with secret: 'hunter2'
    bad_jwt =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJKb2tlbiIsImV4cCI6OCwiaWF0IjozLCJpc3MiOiJKb2tlbiIsImp0aSI6IjJwZXR1bDhhMTY0cmRrcmR1MDAwMDFxMSIsIm5iZiI6Mywicm9sZXMiOlsiYWRtaW4iXSwic3ViIjoidXNlciJ9.mVww76Y5gdA0RfTyod9sjbq9nzBpV4refMhE-CiyDGQ"

    Test.StubTime.set_current_time(3)
    assert {:error, _} = verify_token(bad_jwt)
  end
end
