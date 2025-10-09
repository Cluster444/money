class Account < ApplicationRecord
  enum :kind, { cash: "cash", vendor: "vendor" }

  belongs_to :user

  validates :kind, presence: true, inclusion: { in: kinds.values }
  validates :name, presence: true
  validate :cash_account_maintain_positive_posted_balance

  has_many :debit_transfers, class_name: "Transfer", foreign_key: :debit_account_id, dependent: :destroy
  has_many :credit_transfers, class_name: "Transfer", foreign_key: :credit_account_id, dependent: :destroy
  has_many :debit_schedules, class_name: "Schedule", foreign_key: :debit_account_id, dependent: :destroy
  has_many :credit_schedules, class_name: "Schedule", foreign_key: :credit_account_id, dependent: :destroy

  # Scopes for filtering by kind
  scope :cash, -> { where(kind: :cash) }
  scope :vendor, -> { where(kind: :vendor) }

  def transfers
    Transfer.where("debit_account_id = ? OR credit_account_id = ?", id, id)
  end

  def schedules
    Schedule.where("debit_account_id = ? OR credit_account_id = ?", id, id)
  end

  def posted_balance
    debits - credits
  end

  def pending_balance
    posted_balance + pending_debits_total - pending_credits_total
  end

  def planned_balance(on_date)
    posted_balance + pending_debits_total - pending_credits_total + planned_debits_total(on_date) - planned_credits_total(on_date)
  end

  private

    def cash_account_maintain_positive_posted_balance
      return unless cash? && (debits_changed? || credits_changed?)

      new_debits = debits_changed? ? debits : debits_was
      new_credits = credits_changed? ? credits : credits_was

      if new_debits < new_credits
        errors.add(:base, "Cash account cannot have a negative posted balance")
      end
    end

    def pending_debits_total
      debit_transfers.pending.sum(:amount)
    end

    def pending_credits_total
      credit_transfers.pending.sum(:amount)
    end

    def planned_debits_total(on_date)
      total = 0
      debit_schedules.each do |schedule|
        dates = schedule.transfer_dates(on_date)
        total += dates.count * schedule.amount
      end
      total
    end

    def planned_credits_total(on_date)
      total = 0
      credit_schedules.each do |schedule|
        dates = schedule.transfer_dates(on_date)
        total += dates.count * schedule.amount
      end
      total
    end
end
