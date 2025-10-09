class Schedule < ApplicationRecord
  validates :name, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :starts_on, presence: true
  validates :debit_account, presence: true
  validates :credit_account, presence: true
  validates :period, inclusion: { in: %w[day week month year], allow_blank: true }
  validate :frequency_requirements
  validate :different_accounts

  belongs_to :credit_account, class_name: "Account"
  belongs_to :debit_account, class_name: "Account"
  has_many :transfers, dependent: :nullify

  def transfer_dates(up_to_date)
    dates = []
    current_date = starts_on

    # Handle one-time schedules (no period)
    if period.blank?
      # Include if start date is within the up_to_date range
      if starts_on <= up_to_date
        dates << starts_on
      end
      return dates
    end

    # Handle recurring schedules
    while current_date <= up_to_date
      # Check if we've reached the end date (if specified)
      break if ends_on.present? && current_date > ends_on

      dates << current_date
      current_date = next_date(current_date)
    end

    dates
  end

  def planned_transfers(dates)
    dates.map do |date|
      Transfer.new(
        amount: amount,
        pending_on: date,
        debit_account: debit_account,
        credit_account: credit_account,
        schedule: self,
        state: :pending
      )
    end
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

  private

  def frequency_requirements
    if frequency.present?
      errors.add(:period, "must be present when frequency is set") if period.blank?
      errors.add(:ends_on, "must be present when frequency is set") if ends_on.blank?
    end
  end

  def different_accounts
    errors.add(:credit_account, "must be different from debit account") if debit_account == credit_account
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
