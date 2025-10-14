class Transfer < ApplicationRecord
  enum :state, { pending: "pending", posted: "posted" }

  validates :state, presence: true, inclusion: { in: states.values }
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :pending_on, presence: true
  validates :debit_account, presence: true
  validates :credit_account, presence: true
  validates :posted_on, presence: { message: "must be set for posted transfers" }, if: :posted?
  validate :different_accounts
  validate :credit_card_balance_constraint

  belongs_to :debit_account, class_name: "Account"
  belongs_to :credit_account, class_name: "Account"
  belongs_to :schedule, optional: true

  # Scopes for filtering by state
  scope :pending, -> { where(state: :pending) }
  scope :posted, -> { where(state: :posted) }

  before_update :prevent_posted_update
  before_destroy :handle_deletion

  def post!
    return false unless pending?

    transaction do
      debit_account.increment!(:debits, amount)
      credit_account.increment!(:credits, amount)
      self.posted_on = Date.current
      self.state = :posted
      save!
    end

    true
  end

  private

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

    def handle_deletion
      return unless posted?
      # Reverse the transfer amounts on accounts
      debit_account.decrement!(:debits, amount)
      credit_account.decrement!(:credits, amount)
    end
end
