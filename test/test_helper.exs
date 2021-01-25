ExUnit.start()
Mox.defmock(BookBank.MockAuth, for: BookBank.AuthBehavior)
Mox.defmock(BookBank.MockDatabase, for: BookBank.DatabaseBehavior)
Mox.defmock(BookBankWeb.Utils.MockJwt, for: BookBankWeb.Utils.JwtBehavior)
