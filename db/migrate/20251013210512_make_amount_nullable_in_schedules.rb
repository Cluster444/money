class MakeAmountNullableInSchedules < ActiveRecord::Migration[8.0]
  def change
    change_column_null :schedules, :amount, true
  end
end
