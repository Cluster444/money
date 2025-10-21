module Account::Creditor
  extend ActiveSupport::Concern

  included do
    validate :creditor_maintain_credits_greater_than_debits
  end

  def posted_balance
    credits - debits
  end

  def posted_balance_for_display
    posted_balance
  end

  def pending_balance
    pending_credits_total - pending_debits_total
  end

  def pending_balance_for_display
    pending_balance
  end

  def planned_balance(on_date)
    planned_credits_total(on_date) - planned_debits_total(on_date)
  end

  def planned_balance_for_display(on_date)
    planned_balance(on_date)
  end

  private

  def creditor_maintain_credits_greater_than_debits
    return unless debits_changed? || credits_changed?

    new_debits = debits_changed? ? debits : debits_was
    new_credits = credits_changed? ? credits : credits_was

    if new_credits < new_debits
      errors.add(:base, "Creditor account cannot have credits less than debits")
    end
  end
end
