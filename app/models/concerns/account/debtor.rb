module Account::Debtor
  extend ActiveSupport::Concern

  included do
    validate :debtor_maintain_debits_greater_than_or_equal_to_credits
  end

  def posted_balance
    debits - credits
  end

  def posted_balance_for_display
    posted_balance
  end

  def pending_balance
    pending_debits_total - pending_credits_total
  end

  def pending_balance_for_display
    pending_balance
  end

  def planned_balance(on_date)
    planned_debits_total(on_date) - planned_credits_total(on_date)
  end

  def planned_balance_for_display(on_date)
    planned_balance(on_date)
  end

  private

  def debtor_maintain_debits_greater_than_or_equal_to_credits
    return unless debits_changed? || credits_changed?

    new_debits = debits_changed? ? debits : debits_was
    new_credits = credits_changed? ? credits : credits_was

    if new_debits < new_credits
      case kind.to_s
      when "Account::Cash"
        errors.add(:base, "Cash account cannot have a negative posted balance")
      else
        # Vendor accounts and other debtor accounts can have negative balances
      end
    end
  end
end
