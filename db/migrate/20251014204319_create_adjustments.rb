class CreateAdjustments < ActiveRecord::Migration[8.0]
  def change
    create_table :adjustments do |t|
      t.references :account, null: false, foreign_key: true
      t.bigint :credit_amount
      t.bigint :debit_amount
      t.text :note

      t.timestamps
    end
  end
end
