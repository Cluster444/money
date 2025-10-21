class Account::Cash < Account
  include Account::Debtor

  self.table_name = "accounts"
end
