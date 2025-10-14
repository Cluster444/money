class Schedule < ApplicationRecord
  validates :name, presence: true
  validates :amount, presence: true, unless: -> { relative_account_id.present? }
  validates :amount, numericality: { greater_than: 0, allow_blank: true }
  validates :starts_on, presence: true
  validates :debit_account, presence: true
  validates :credit_account, presence: true
  validates :period, inclusion: { in: %w[day week month year], allow_blank: true }
  validate :frequency_requirements
  validate :different_accounts

  belongs_to :relative_account, class_name: "Account", optional: true
  belongs_to :credit_account, class_name: "Account"
  belongs_to :debit_account, class_name: "Account"
  has_many :transfers, dependent: :nullify

  scope :active, -> {
    where(
      "(ends_on IS NULL) OR (ends_on > ?)",
      Date.current
    )
  }

  def transfer_dates(up_to_date)
    dates = []
    current_date = starts_on

    # Handle relative account date rules
    if relative_account.present? && amount.blank?
      # Rule: zero balance and no amount -> no dates
      return [] if relative_account.posted_balance.zero?

      # Rule: non-zero balance and no amount -> only one date (the next one)
      if relative_account.posted_balance.nonzero?
        # Find the next scheduled date on or after today
        next_date = find_next_date_from(Date.current)
        return next_date && next_date <= up_to_date ? [ next_date ] : []
      end
    end

    # Handle one-time schedules (no period)
    if period.blank?
      # Include if start date is within the up_to_date range
      if starts_on <= up_to_date
        dates << starts_on
      end
      return dates
    end

    # Handle recurring schedules (normal behavior or fixed amount with relative account)
    while current_date <= up_to_date
      # Check if we've reached the end date (if specified)
      break if ends_on.present? && current_date > ends_on

      dates << current_date
      current_date = next_date(current_date)
    end

    dates
  end

  def planned_transfers(dates)
    return [] if dates.empty?

    # Special case: zero balance and no amount -> no transfers at all
    if relative_account.present? && amount.blank? && relative_account.posted_balance.zero?
      return []
    end

    dates.map.with_index do |date, index|
      calculated_amount = calculate_transfer_amount(index)

      # Skip individual transfers with zero amount (for relative-only schedules after first transfer)
      next if calculated_amount.zero?

      Transfer.new(
        amount: calculated_amount,
        pending_on: date,
        debit_account: debit_account,
        credit_account: credit_account,
        schedule: self,
        state: :pending
      )
    end.compact
  end

  def next_materialized_on
    return nil if period.blank? && starts_on.past?

    base_date = last_materialized_on || starts_on
    return nil if base_date && ends_on.present? && base_date > ends_on

    next_date = period.blank? ? starts_on : next_date(base_date)
    return nil if ends_on.present? && next_date > ends_on

    next_date
  end

  def create_pending_transfers
    transaction do
      today = Date.current
      # Get dates that need to be materialized (from last_materialized_on + 1 day up to today)
      from_date = last_materialized_on ? last_materialized_on + 1.day : starts_on
      to_date = today

      # Get all transfer dates in the range
      dates_to_materialize = transfer_dates(to_date).select { |date| date >= from_date && date <= to_date }

      # Create and save the transfers
      planned_transfers(dates_to_materialize).each do |transfer|
        transfer.save!
      end

      # Update last_materialized_on to today
      update!(last_materialized_on: today)
    end
  end

  def calculate_transfer_amount(index)
    # If no relative account, use fixed amount
    return amount unless relative_account.present?

    # Get current balance of relative account
    current_balance = relative_account.posted_balance

    # Rule 2: non-zero balance and no amount -> only first transfer uses balance
    if current_balance.nonzero? && amount.blank?
      return index.zero? ? current_balance : 0
    end

    # Rule 3: zero balance and fixed amount -> use amount for all transfers
    if current_balance.zero? && amount.present?
      return amount
    end

    # Rule 4: non-zero balance and fixed amount -> first transfer uses balance, rest use amount
    if current_balance.nonzero? && amount.present?
      return index.zero? ? current_balance : amount
    end

    # Rule 1: zero balance and no amount -> handled in planned_transfers method
    # Fallback
    amount
  end

  private

  def frequency_requirements
    if frequency.present?
      errors.add(:period, "must be present when frequency is set") if period.blank?
    end
  end

  def different_accounts
    errors.add(:credit_account, "must be different from debit account") if debit_account == credit_account
  end

  def find_next_date_from(from_date)
    # For one-time schedules, just check if starts_on is on or after from_date
    return starts_on if period.blank? && starts_on >= from_date

    # For recurring schedules, find the next occurrence
    return nil if period.blank?

    current_date = starts_on
    while current_date < from_date
      current_date = next_date(current_date)
    end

    # Check if this date is within any end date constraint
    return nil if ends_on.present? && current_date > ends_on

    current_date
  end

  def next_date(date)
    case period
    when "day"
      date + frequency.days
    when "week"
      date + frequency.weeks
    when "month"
      date + frequency.months
    when "year"
      date + frequency.years
    else
      date
    end
  end
end
