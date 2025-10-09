class CreateSchedules < ActiveRecord::Migration[8.0]
  def change
    create_table :schedules do |t|
      t.string :name, null: false
      t.bigint :amount, null: false
      t.string :period
      t.integer :frequency
      t.date :starts_on, null: false
      t.date :ends_on
      t.date :last_materialized_on

      t.references :credit_account, null: false, foreign_key: { to_table: :accounts }
      t.references :debit_account, null: false, foreign_key: { to_table: :accounts }

      t.timestamps
    end
  end
end
