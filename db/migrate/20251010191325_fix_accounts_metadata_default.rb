class FixAccountsMetadataDefault < ActiveRecord::Migration[8.0]
  def change
    change_column_default :accounts, :metadata, {}
  end
end
