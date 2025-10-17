class AddPostedBalanceToAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :accounts, :posted_balance, :integer
  end
end
