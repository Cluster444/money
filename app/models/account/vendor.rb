class Account::Vendor < Account
  include Account::Debtor

  self.table_name = "accounts"
end
