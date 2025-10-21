class Account::Customer < Account
  include Account::Creditor

  self.table_name = "accounts"
end
