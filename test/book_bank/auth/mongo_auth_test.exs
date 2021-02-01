defmodule BookBank.MongoAuthTest do
  use ExUnit.Case, async: false
  import Mox
  import Test.Utils
  import BookBank.MongoAuth

  setup :verify_on_exit!

  setup do
    {:ok, _pid} = Mongo.start_link(name: :mongo, database: "test", url: Application.get_env(:book_bank, BookBank.MongoDatabase)[:url])
    BookBank.Utils.Mongo.init()

    on_exit(fn ->
      {:ok, _pid} = Mongo.start_link(name: :mongo, database: "test", url: Application.get_env(:book_bank, BookBank.MongoDatabase)[:url])
      Mongo.drop_database(:mongo, "test")
    end)
  end

  def assert_create_user(username, roles, password \\ "hunter2") do
    assert {:ok, %BookBank.User{username: _username, roles: _roles}} = create_user(username, password, roles)
  end

  def assert_get_user(username, roles) do
    assert {:ok, %BookBank.User{username: ^username, roles: ^roles}} = get_user(username)
  end

  test "Can retrieve created user" do
    assert_create_user("admin", ["admin"])
    assert_get_user("admin", ["roles"])
  end

  test "Does not store raw password" do
    assert_create_user("admin", ["admin"])

    assert %{"password" => password} = Mongo.find_one(:mongo, "users", %{username: "admin"})
    assert password !== "hunter2"
  end

  test "Update add roles" do
    assert_create_user("pleb", ["plebian"])

    assert :ok = update_user("pleb", add_roles: ["plebian", "librarian", "admin"])
    assert_get_user("pleb", ["plebian", "librarian", "admin"])
  end

end
