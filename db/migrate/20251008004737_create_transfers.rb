class CreateTransfers < ActiveRecord::Migration[8.0]
  def change
    create_table :transfers do |t|
      t.string :state, null: false, default: "pending"
      t.bigint :amount, null: false
      t.date :pending_on, null: false
      t.date :posted_on

      t.references :debit_account, null: false, foreign_key: { to_table: :accounts }
      t.references :credit_account, null: false, foreign_key: { to_table: :accounts }
      t.references :schedule, foreign_key: true

      t.timestamps
    end
  end
end
