class CreateAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :accounts do |t|
      t.string :kind, null: false
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.bigint :debits, null: false, default: 0
      t.bigint :credits, null: false, default: 0
      t.json :metadata, null: false, default: "{}"

      t.timestamps
    end
  end
end
