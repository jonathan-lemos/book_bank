ExUnit.start()
Mox.defmock(BookBank.MockAuth, for: BookBank.Auth)
Mox.defmock(BookBank.MockDatabase, for: BookBank.Database)
Mox.defmock(BookBankWeb.Utils.MockAuth, for: BookBankWeb.Utils.AuthBehavior)
