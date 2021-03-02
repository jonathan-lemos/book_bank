defmodule BookBank.MongoAuthTest do
  use ExUnit.Case, async: false
  import Mox
  import BookBank.MongoAuth

  @moduletag :mongo

  setup :verify_on_exit!

  setup do
    {:ok, _} =
      start_supervised(
        {Mongo,
         name: :mongo,
         database: "test",
         url: Application.get_env(:book_bank, BookBank.MongoDatabase)[:url]}
      )

    :ok = BookBank.Utils.Mongo.init!()

    on_exit(fn ->
      {:ok, _pid} =
        Mongo.start_link(
          name: :mongo,
          database: "test",
          url: Application.get_env(:book_bank, BookBank.MongoDatabase)[:url]
        )

      Mongo.drop_database(:mongo, "test")
    end)
  end

  def assert_create_user(username, roles, password \\ "hunter2") do
    assert {:ok, %BookBank.User{username: ^username, roles: ^roles}} =
             create_user(username, password, roles)
  end

  def assert_get_user(username, roles) do
    assert {:ok, %BookBank.User{username: ^username, roles: ^roles}} = get_user(username)
  end

  test "Can retrieve created user" do
    assert_create_user("admin", ["admin"])
    assert_get_user("admin", ["admin"])
  end

  test "Can authenticate created user" do
    assert_create_user("admin", ["admin"], "hunter2")

    assert {:ok, %BookBank.User{username: "admin", roles: ["admin"]}} =
             authenticate_user("admin", "hunter2")
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

  test "Update remove roles" do
    assert_create_user("pleb", ["plebian", "admin", "librarian"])

    assert :ok = update_user("pleb", remove_roles: ["admin", "librarian"])
    assert_get_user("pleb", ["plebian"])
  end

  test "Update add+remove roles" do
    assert_create_user("pleb", ["admin", "librarian"])

    assert :ok = update_user("pleb", remove_roles: ["admin"], add_roles: ["plebian"])
    assert_get_user("pleb", ["librarian", "plebian"])
  end

  test "Update change password" do
    assert_create_user("pleb", ["plebian"], "hunter2")

    assert :ok = update_user("pleb", set_password: "hunter3")

    assert {:ok, %BookBank.User{username: "pleb", roles: ["plebian"]}} =
             authenticate_user("pleb", "hunter3")
  end
end
