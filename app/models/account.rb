class Account < ApplicationRecord
  include Monetize

  self.inheritance_column = "kind"

  # Use the base class name for form fields to avoid STI class names in field names
  def self.model_name
    ActiveModel::Name.new(self, nil, "Account")
  end

  belongs_to :organization
  has_one :user, through: :organization

  validates :name, presence: true
  validates :debits, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :credits, presence: true, numericality: { greater_than_or_equal_to: 0 }

  monetize :debits, :credits

  has_many :debit_transfers, class_name: "Transfer", foreign_key: :debit_account_id, dependent: :destroy
  has_many :credit_transfers, class_name: "Transfer", foreign_key: :credit_account_id, dependent: :destroy
  has_many :debit_schedules, class_name: "Schedule", foreign_key: :debit_account_id, dependent: :destroy
  has_many :credit_schedules, class_name: "Schedule", foreign_key: :credit_account_id, dependent: :destroy
  has_many :adjustments, dependent: :destroy

  # Scopes for filtering by kind
  scope :cash, -> { where(kind: "Account::Cash") }
  scope :vendor, -> { where(kind: "Account::Vendor") }
  scope :credit_card, -> { where(kind: "Account::CreditCard") }
  scope :customer, -> { where(kind: "Account::Customer") }

  scope :with_transfers, -> { includes(:debit_transfers, :credit_transfers) }
  scope :with_schedules, -> { includes(:debit_schedules, :credit_schedules) }

  def transfers
    Transfer.where("debit_account_id = ? OR credit_account_id = ?", id, id)
  end

  def schedules
    Schedule.where("debit_account_id = ? OR credit_account_id = ?", id, id)
  end

  def create_adjustment!(credit_amount: nil, debit_amount: nil, note:)
    Adjustment.create!(
      account: self,
      credit_amount: credit_amount,
      debit_amount: debit_amount,
      note: note
    )
  end

  # Return nil for credit_limit on non-credit-card accounts
  def credit_limit
    nil
  end

  # Add methods that were provided by the enum for compatibility
  def cash?
    kind == "Account::Cash"
  end

  def vendor?
    kind == "Account::Vendor"
  end

  def credit_card?
    kind == "Account::CreditCard"
  end

  def customer?
    kind == "Account::Customer"
  end

  # Add class method for compatibility with views expecting enum
  def self.kinds
    {
      "Account::Cash" => "cash",
      "Account::Vendor" => "vendor",
      "Account::CreditCard" => "credit_card",
      "Account::Customer" => "customer"
    }
  end

  # Returns the short kind name for CSS classes and display
  def kind_short
    self.class.kinds[kind.to_s] || kind.to_s.underscore
  end

  def posted_balance=(amount)
    if amount.present?
      if amount.to_f < 0
        raise ArgumentError, "Amount must be positive or zero."
      end

      case kind.to_s
      when "Account::Cash", "Account::Vendor"
        self.debits = amount
        self.credits = 0
      when "Account::CreditCard", "Account::Customer"
        self.credits = amount
        self.debits = 0
      end
    end
  end

  def pending_debits_total
    debit_transfers.select(&:pending?).sum(&:amount)
  end

  def pending_credits_total
    credit_transfers.select(&:pending?).sum(&:amount)
  end

  def planned_debits_total(on_date)
    total = BigDecimal("0")
    debit_schedules.each do |schedule|
      dates = schedule.transfer_dates(on_date)
      # Only include future dates (from today onwards) for planned balance
      future_dates = dates.select { |date| date >= Date.current }
      total += future_dates.count * schedule.amount if schedule.amount.present?
    end
    total
  end

  def planned_credits_total(on_date)
    total = BigDecimal("0")
    credit_schedules.each do |schedule|
      dates = schedule.transfer_dates(on_date)
      # Only include future dates (from today onwards) for planned balance
      future_dates = dates.select { |date| date >= Date.current }
      total += future_dates.count * schedule.amount if schedule.amount.present?
    end
    total
  end
end
