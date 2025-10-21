class Adjustment < ApplicationRecord
  include Monetize

  belongs_to :account

  validates :account, presence: true
  validates :note, presence: true
  validate :at_least_one_amount_present

  attribute :target_balance, :decimal

  monetize :credit_amount, :debit_amount

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
      current_credits_cents = account.credits_before_type_cast || 0
      new_credits_cents = current_credits_cents + credit_amount_before_type_cast
      account.update_column(:credits, new_credits_cents)
    elsif debit_amount.present?
      current_debits_cents = account.debits_before_type_cast || 0
      new_debits_cents = current_debits_cents + debit_amount_before_type_cast
      account.update_column(:debits, new_debits_cents)
    end
  end

  def handle_balance_update
    # Handle credit amount changes
    if saved_change_to_credit_amount?
      old_credit_cents = credit_amount_before_last_save || 0
      new_credit_cents = credit_amount_before_type_cast || 0

      current_credits_cents = account.credits_before_type_cast || 0

      # Remove old amount and add new amount
      current_credits_cents = current_credits_cents - old_credit_cents + new_credit_cents
      account.update_column(:credits, current_credits_cents)
    end

    # Handle debit amount changes
    if saved_change_to_debit_amount?
      old_debit_cents = debit_amount_before_last_save || 0
      new_debit_cents = debit_amount_before_type_cast || 0

      current_debits_cents = account.debits_before_type_cast || 0

      # Remove old amount and add new amount
      current_debits_cents = current_debits_cents - old_debit_cents + new_debit_cents
      account.update_column(:debits, current_debits_cents)
    end
  end

  def reverse_account_balance
    if credit_amount.present?
      current_credits_cents = account.credits_before_type_cast || 0
      new_credits_cents = current_credits_cents - credit_amount_before_type_cast
      account.update_column(:credits, new_credits_cents)
    elsif debit_amount.present?
      current_debits_cents = account.debits_before_type_cast || 0
      new_debits_cents = current_debits_cents - debit_amount_before_type_cast
      account.update_column(:debits, new_debits_cents)
    end
  end
end
