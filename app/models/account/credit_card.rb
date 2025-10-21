class Account::CreditCard < Account
  include Account::Creditor

  self.table_name = "accounts"

  # Credit card specific validations
  validates :due_day, presence: true, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 1,
    less_than_or_equal_to: 31
  }

  validates :statement_day, presence: true, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 1,
    less_than_or_equal_to: 31
  }

  validates :credit_limit, presence: true, numericality: {
    greater_than: 0
  }

  after_create :create_payment_schedule_for_credit_card

  def due_day
    metadata["due_day"]&.to_i
  end

  def due_day=(value)
    self.metadata = (metadata || {}).merge("due_day" => value)
  end

  def statement_day
    metadata["statement_day"]&.to_i
  end

  def statement_day=(value)
    self.metadata = (metadata || {}).merge("statement_day" => value)
  end

  def credit_limit
    metadata["credit_limit"]&.to_f
  end

  def credit_limit=(value)
    self.metadata = (metadata || {}).merge("credit_limit" => value)
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

  def create_payment_schedule_for_credit_card
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
end
