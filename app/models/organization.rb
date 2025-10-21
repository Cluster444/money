class Organization < ApplicationRecord
  belongs_to :user
  has_many :accounts, dependent: :destroy

  def transfers
    Transfer.where("debit_account_id IN (?) OR credit_account_id IN (?)", account_ids, account_ids)
  end
end
