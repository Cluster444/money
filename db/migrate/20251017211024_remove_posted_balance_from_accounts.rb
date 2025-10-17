class RemovePostedBalanceFromAccounts < ActiveRecord::Migration[8.0]
  def change
    remove_column :accounts, :posted_balance, :integer
  end
end
