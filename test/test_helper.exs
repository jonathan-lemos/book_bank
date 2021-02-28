ExUnit.configure(exclude: [:elastic, :mongo])
ExUnit.start()

BookBank.DI.services()
|> Enum.filter(fn {behavior, _} -> behavior !== Joken.CurrentTime end)
|> Enum.each(fn {behavior, service} -> Mox.defmock(service, for: behavior) end)

# Mox.defmock(BookBankWeb.Utils.MockJwtTime, for: Joken.CurrentTime)
# Mox.stub_with(BookBankWeb.Utils.MockJwtTime, Test.StubTime)
{:ok, _} = Test.StubTime.start_link()
