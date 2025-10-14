class AddRelativeAccountToSchedules < ActiveRecord::Migration[8.0]
  def change
    add_reference :schedules, :relative_account, null: true, foreign_key: { to_table: :accounts }
  end
end
