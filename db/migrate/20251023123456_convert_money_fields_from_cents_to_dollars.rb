class ConvertMoneyFieldsFromCentsToDollars < ActiveRecord::Migration[8.1]
  def up
    # Change column types from bigint to decimal(15,2)
    change_column :accounts, :credits, :decimal, precision: 15, scale: 2
    change_column :accounts, :debits, :decimal, precision: 15, scale: 2
    change_column :adjustments, :credit_amount, :decimal, precision: 15, scale: 2
    change_column :adjustments, :debit_amount, :decimal, precision: 15, scale: 2
    change_column :schedules, :amount, :decimal, precision: 15, scale: 2
    change_column :transfers, :amount, :decimal, precision: 15, scale: 2

    # Convert values from cents to dollars by dividing by 100
    execute "UPDATE accounts SET credits = credits / 100.0"
    execute "UPDATE accounts SET debits = debits / 100.0"
    execute "UPDATE adjustments SET credit_amount = credit_amount / 100.0"
    execute "UPDATE adjustments SET debit_amount = debit_amount / 100.0"
    execute "UPDATE schedules SET amount = amount / 100.0"
    execute "UPDATE transfers SET amount = amount / 100.0"
  end

  def down
    # Convert values from dollars back to cents by multiplying by 100
    execute "UPDATE accounts SET credits = credits * 100"
    execute "UPDATE accounts SET debits = debits * 100"
    execute "UPDATE adjustments SET credit_amount = credit_amount * 100"
    execute "UPDATE adjustments SET debit_amount = debit_amount * 100"
    execute "UPDATE schedules SET amount = amount * 100"
    execute "UPDATE transfers SET amount = amount * 100"

    # Change column types back to bigint
    change_column :accounts, :credits, :bigint
    change_column :accounts, :debits, :bigint
    change_column :adjustments, :credit_amount, :bigint
    change_column :adjustments, :debit_amount, :bigint
    change_column :schedules, :amount, :bigint
    change_column :transfers, :amount, :bigint
  end
end
