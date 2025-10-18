class Account < ApplicationRecord
  enum :kind, { cash: "cash", vendor: "vendor", credit_card: "credit_card" }

  belongs_to :organization
  has_one :user, through: :organization

  validates :kind, presence: true, inclusion: { in: kinds.values }
  validates :name, presence: true

  # Credit card specific validations
  validates :due_day, presence: true, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 1,
    less_than_or_equal_to: 31
  }, if: :credit_card?

  validates :statement_day, presence: true, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 1,
    less_than_or_equal_to: 31
  }, if: :credit_card?

  validates :credit_limit, presence: true, numericality: {
    greater_than: 0
  }, if: :credit_card?
  validate :cash_account_maintain_positive_posted_balance

  after_create :create_payment_schedule_for_credit_card

  has_many :debit_transfers, class_name: "Transfer", foreign_key: :debit_account_id, dependent: :destroy
  has_many :credit_transfers, class_name: "Transfer", foreign_key: :credit_account_id, dependent: :destroy
  has_many :debit_schedules, class_name: "Schedule", foreign_key: :debit_account_id, dependent: :destroy
  has_many :credit_schedules, class_name: "Schedule", foreign_key: :credit_account_id, dependent: :destroy
  has_many :adjustments, dependent: :destroy

  # Scopes for filtering by kind
  scope :cash, -> { where(kind: :cash) }
  scope :vendor, -> { where(kind: :vendor) }
  scope :credit_card, -> { where(kind: :credit_card) }

  scope :with_transfers, -> { includes(:debit_transfers, :credit_transfers) }
  scope :with_schedules, -> { includes(:debit_schedules, :credit_schedules) }

  def transfers
    Transfer.where("debit_account_id = ? OR credit_account_id = ?", id, id)
  end

  def schedules
    Schedule.where("debit_account_id = ? OR credit_account_id = ?", id, id)
  end

  def posted_balance
    credit_card? ? credits - debits : debits - credits
  end

  def posted_balance_for_display
    if vendor?
      credits - debits
    else
      posted_balance
    end
  end

  def pending_balance
    pending_debits_total - pending_credits_total
  end

  def pending_balance_for_display
    if vendor?
      pending_credits_total - pending_debits_total
    else
      pending_balance
    end
  end

  def planned_balance_30_days
    thirty_days_from_now = Date.current + 30.days
    planned_debits_total(thirty_days_from_now) - planned_credits_total(thirty_days_from_now)
  end

  def planned_balance(on_date)
    planned_debits_total(on_date) - planned_credits_total(on_date)
  end

  def planned_balance_for_display(on_date)
    if vendor?
      planned_credits_total(on_date) - planned_debits_total(on_date)
    else
      planned_balance(on_date)
    end
  end

  def create_adjustment!(credit_amount: nil, debit_amount: nil, note:)
    Adjustment.create!(
      account: self,
      credit_amount: credit_amount,
      debit_amount: debit_amount,
      note: note
    )
  end

  def posted_balance=(amount)
    if amount.present?
      # Convert to cents and store as integer
      amount_in_cents = (amount.to_f * 100).round

      if amount_in_cents < 0
        raise ArgumentError, "Amount must be positive or zero."
      end

      case kind
      when "cash", "vendor"
        self.debits = amount_in_cents
        self.credits = 0
      when "credit_card"
        self.credits = amount_in_cents
        self.debits = 0
      end
    end
  end

  def due_day
    metadata["due_day"]&.to_i if credit_card?
  end

  def due_day=(value)
    if credit_card?
      self.metadata = (metadata || {}).merge("due_day" => value)
    end
  end

  def statement_day
    metadata["statement_day"]&.to_i if credit_card?
  end

  def statement_day=(value)
    if credit_card?
      self.metadata = (metadata || {}).merge("statement_day" => value)
    end
  end

  def credit_limit
    metadata["credit_limit"]&.to_f if credit_card?
  end

  def credit_limit=(value)
    if credit_card?
      self.metadata = (metadata || {}).merge("credit_limit" => value)
    end
  end



  def next_statement_date
    return nil unless statement_day

    today = Date.current
    current_month_statement = Date.new(today.year, today.month, statement_day)

    if current_month_statement >= today
      current_month_statement
    else
      Date.new(today.year, today.month + 1, statement_day)
    end
  end

  def next_due_date
    return nil unless due_day

    today = Date.current
    current_month_due = Date.new(today.year, today.month, due_day)

    if current_month_due >= today
      current_month_due
    else
      Date.new(today.year, today.month + 1, due_day)
    end
  end

  def days_until_statement
    return nil unless next_statement_date
    (next_statement_date - Date.current).to_i
  end

  def days_until_due
    return nil unless next_due_date
    (next_due_date - Date.current).to_i
  end

  def next_payment_date
    return nil unless statement_day

    today = Date.current
    current_month_statement = Date.new(today.year, today.month, statement_day)
    payment_date = current_month_statement - 1.day

    if payment_date >= today
      payment_date
    else
      next_month_statement = Date.new(today.year, today.month + 1, statement_day)
      next_month_statement - 1.day
    end
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

    def credit_card_maintain_credits_greater_than_debits
      return unless credit_card? && (debits_changed? || credits_changed?)

      new_debits = debits_changed? ? debits : debits_was
      new_credits = credits_changed? ? credits : credits_was

      if new_credits < new_debits
        errors.add(:base, "Credit card cannot have credits less than debits")
      end
    end

    def credit_card_metadata_validation
      nil unless credit_card?

      # This method can be used for additional metadata validations
      # that aren't covered by the individual field validations
    end

    def create_payment_schedule_for_credit_card
      return unless credit_card?
      return unless due_day && statement_day

      cash_account = organization.accounts.cash.first
      return unless cash_account

      Schedule.create!(
        name: "Payment for #{name}",
        debit_account: self,
        credit_account: cash_account,
        relative_account: self,
        starts_on: next_payment_date,
        period: "month",
        frequency: 1
      )
    end

    def pending_debits_total
      debit_transfers.select(&:pending?).sum(&:amount)
    end

    def pending_credits_total
      credit_transfers.select(&:pending?).sum(&:amount)
    end

    def planned_debits_total(on_date)
      total = 0
      debit_schedules.each do |schedule|
        dates = schedule.transfer_dates(on_date)
        # Only include future dates (from today onwards) for planned balance
        future_dates = dates.select { |date| date >= Date.current }
        total += future_dates.count * schedule.amount if schedule.amount.present?
      end
      total
    end

    def planned_credits_total(on_date)
      total = 0
      credit_schedules.each do |schedule|
        dates = schedule.transfer_dates(on_date)
        # Only include future dates (from today onwards) for planned balance
        future_dates = dates.select { |date| date >= Date.current }
        total += future_dates.count * schedule.amount if schedule.amount.present?
      end
      total
    end
end
