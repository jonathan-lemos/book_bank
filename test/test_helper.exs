ExUnit.configure(exclude: [:elastic, :mongo])
ExUnit.start()

Application.get_env(:book_bank, :services) |> Enum.each(fn {behavior, mock} -> Mox.defmock(mock, for: behavior) end)

# Mox.defmock(BookBankWeb.Utils.MockJwtTime, for: Joken.CurrentTime)
# Mox.stub_with(BookBankWeb.Utils.MockJwtTime, Test.StubTime)
{:ok, _} = Test.StubTime.start_link()
