class Transfer < ApplicationRecord
  include Monetize

  enum :state, { pending: "pending", posted: "posted" }

  validates :state, presence: true, inclusion: { in: states.values }
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :pending_on, presence: true
  validates :debit_account, presence: true
  validates :credit_account, presence: true
  validates :posted_on, presence: { message: "must be set for posted transfers" }, if: :posted?
  validate :different_accounts
  validate :credit_card_balance_constraint
  validate :cash_account_balance_constraint

  monetize :amount

  belongs_to :debit_account, class_name: "Account"
  belongs_to :credit_account, class_name: "Account"
  belongs_to :schedule, optional: true

  # Scopes for filtering by state
  scope :pending, -> { where(state: :pending) }
  scope :posted, -> { where(state: :posted) }

  after_create :update_account_posted_balance, if: :posted?
  before_update :prevent_posted_update
  before_destroy :handle_deletion

  def post!
    return false unless pending?

    # Check balance constraints before posting
    return false unless valid_for_posting?

    transaction do
      # Correct accounting:
      # - debit_account (TO account) gets debits (money receiving)
      # - credit_account (FROM account) gets credits (money leaving)
      current_debit_cents = debit_account.debits_before_type_cast || 0
      new_debit_cents = current_debit_cents + amount_before_type_cast
      debit_account.update_column(:debits, new_debit_cents)

      current_credit_cents = credit_account.credits_before_type_cast || 0
      new_credit_cents = current_credit_cents + amount_before_type_cast
      credit_account.update_column(:credits, new_credit_cents)

      self.posted_on = Date.current
      self.state = :posted
      save!
    end

    true
  end

  def valid_for_posting?
    # Check cash account balance constraint
    if credit_account&.cash?
      current_balance = (credit_account.debits || 0) - (credit_account.credits || 0)
      new_balance = current_balance - amount
      if new_balance < 0
        errors.add(:base, "Cash account cannot have negative balance")
        return false
      end
    end

    true
  end

  private

  def update_account_posted_balance
    # For newly created posted transfers, update account balances
    transaction do
      # Correct accounting:
      # - debit_account (TO account) gets debits (money receiving)
      # - credit_account (FROM account) gets credits (money leaving)
      current_debit_cents = debit_account.debits_before_type_cast || 0
      new_debit_cents = current_debit_cents + amount_before_type_cast
      debit_account.update_column(:debits, new_debit_cents)

      current_credit_cents = credit_account.credits_before_type_cast || 0
      new_credit_cents = current_credit_cents + amount_before_type_cast
      credit_account.update_column(:credits, new_credit_cents)
    end
  end

    def prevent_posted_update
      return unless posted?
      return unless changed?
      # Allow the state change from pending to posted during posting
      return if state_changed? && state_was == "pending" && state == "posted"

      errors.add(:base, "Posted transfers cannot be modified")
      throw(:abort)
    end

    def different_accounts
      errors.add(:credit_account, "must be different from debit account") if debit_account == credit_account
    end

  def credit_card_balance_constraint
    return unless pending? && (debit_account_changed? || credit_account_changed? || amount_changed?)

    # Check if this would violate credit card constraint after posting
    if debit_account&.credit_card?
      new_debits = (debit_account.debits || 0) + amount
      new_credits = debit_account.credits || 0
      if new_credits < new_debits
        errors.add(:base, "This transfer would cause credit card to have credits less than debits")
      end
    end

    if credit_account&.credit_card?
      new_credits = (credit_account.credits || 0) + amount
      new_debits = credit_account.debits || 0
      if new_credits < new_debits
        errors.add(:base, "This transfer would cause credit card to have credits less than debits")
      end
    end
  end

  def cash_account_balance_constraint
    # Only check this constraint when creating a NEW posted transfer (not when posting an existing pending transfer)
    # Pending transfers can be created even if they would cause negative balance
    # The actual check happens during posting in the valid_for_posting? method
    return unless posted? && !persisted? && !state_changed?

    # Check if FROM account (credit_account) is a cash account and would go negative
    if credit_account&.cash?
      current_balance_cents = (credit_account.debits_before_type_cast || 0) - (credit_account.credits_before_type_cast || 0)
      new_balance_cents = current_balance_cents - amount_before_type_cast
      if new_balance_cents < 0
        errors.add(:base, "Cash account cannot have negative balance")
      end
    end
  end

  def handle_deletion
    return unless posted?
    # Reverse the transfer amounts on accounts
    # Remove debits from TO account and credits from FROM account
    current_debit_cents = debit_account.debits_before_type_cast || 0
    new_debit_cents = current_debit_cents - amount_before_type_cast
    debit_account.update_column(:debits, new_debit_cents)

    current_credit_cents = credit_account.credits_before_type_cast || 0
    new_credit_cents = current_credit_cents - amount_before_type_cast
    credit_account.update_column(:credits, new_credit_cents)
  end
end
