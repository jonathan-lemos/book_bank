ExUnit.start()
Mox.defmock(BookBank.MockAuth, for: BookBank.AuthBehavior)
Mox.defmock(BookBank.MockDatabase, for: BookBank.DatabaseBehavior)
Mox.defmock(BookBankWeb.Utils.MockJwt, for: BookBankWeb.Utils.JwtBehavior)
Mox.defmock(BookBank.Auth.MockUserWhitelist, for: BookBank.Auth.UserWhitelistBehavior)

# Mox.defmock(BookBankWeb.Utils.MockJwtTime, for: Joken.CurrentTime)
# Mox.stub_with(BookBankWeb.Utils.MockJwtTime, Test.StubTime)
{:ok, _} = Test.StubTime.start_link()
