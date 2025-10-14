class Adjustment < ApplicationRecord
  belongs_to :account

  validates :account, presence: true
  validates :note, presence: true
  validate :at_least_one_amount_present

  attribute :target_balance, :decimal

  after_create :update_account_balance
  after_update :handle_balance_update
  after_destroy :reverse_account_balance

  def net_effect
    if account.cash? || account.vendor?
      # For cash/vendor: debits increase balance, credits decrease
      (debit_amount || 0) - (credit_amount || 0)
    else
      # For credit cards: credits increase balance, debits decrease
      (credit_amount || 0) - (debit_amount || 0)
    end
  end

  private

  def at_least_one_amount_present
    if credit_amount.blank? && debit_amount.blank?
      errors.add(:base, "Adjustment must change the account balance")
    end

    if credit_amount.present? && debit_amount.present?
      errors.add(:base, "Cannot have both credit amount and debit amount")
    end
  end

  def update_account_balance
    if credit_amount.present?
      account.increment!(:credits, credit_amount)
    elsif debit_amount.present?
      account.increment!(:debits, debit_amount)
    end
  end

  def handle_balance_update
    # Handle credit amount changes
    if saved_change_to_credit_amount?
      old_credit = credit_amount_before_last_save
      new_credit = credit_amount

      if old_credit.present?
        account.decrement!(:credits, old_credit)
      end
      if new_credit.present?
        account.increment!(:credits, new_credit)
      end
    end

    # Handle debit amount changes
    if saved_change_to_debit_amount?
      old_debit = debit_amount_before_last_save
      new_debit = debit_amount

      if old_debit.present?
        account.decrement!(:debits, old_debit)
      end
      if new_debit.present?
        account.increment!(:debits, new_debit)
      end
    end
  end

  def reverse_account_balance
    if credit_amount.present?
      account.decrement!(:credits, credit_amount)
    elsif debit_amount.present?
      account.decrement!(:debits, debit_amount)
    end
  end
end
