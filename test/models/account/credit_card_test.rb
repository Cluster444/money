require "test_helper"

class Account::CreditCardTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:lazaro_credit_card)
  end

  test "should be valid with required attributes" do
    assert @account.valid?
  end

  test "should be credit card account" do
    assert @account.credit_card?
    assert_not @account.cash?
    assert_not @account.vendor?
    assert_not @account.customer?
  end

  test "should have correct kind" do
    assert_equal "Account::CreditCard", @account.kind
  end

  # Credit card field validation tests
  test "should validate due_day presence for credit card" do
    credit_card = Account::CreditCard.new(name: "Test Credit Card", organization: organizations(:lazaro_personal))

    credit_card.valid?

    assert_includes credit_card.errors[:due_day], "can't be blank"
  end

  test "should validate statement_day presence for credit card" do
    credit_card = Account::CreditCard.new(name: "Test Credit Card", organization: organizations(:lazaro_personal))

    credit_card.valid?

    assert_includes credit_card.errors[:statement_day], "can't be blank"
  end

  test "should validate due_day numericality for credit card" do
    credit_card = Account::CreditCard.new(name: "Test Credit Card", organization: organizations(:lazaro_personal))
    credit_card.due_day = "invalid"

    credit_card.valid?

    assert_includes credit_card.errors[:due_day], "must be greater than or equal to 1"
  end

  test "should validate statement_day numericality for credit card" do
    credit_card = Account::CreditCard.new(name: "Test Credit Card", organization: organizations(:lazaro_personal))
    credit_card.statement_day = "invalid"

    credit_card.valid?

    assert_includes credit_card.errors[:statement_day], "must be greater than or equal to 1"
  end

  test "should validate due_day range for credit card" do
    credit_card = Account::CreditCard.new(name: "Test Credit Card", organization: organizations(:lazaro_personal))
    credit_card.due_day = 32

    credit_card.valid?

    assert_includes credit_card.errors[:due_day], "must be less than or equal to 31"
  end

  test "should validate statement_day range for credit card" do
    credit_card = Account::CreditCard.new(name: "Test Credit Card", organization: organizations(:lazaro_personal))
    credit_card.statement_day = 0

    credit_card.valid?

    assert_includes credit_card.errors[:statement_day], "must be greater than or equal to 1"
  end

  test "should validate valid credit card fields" do
    credit_card = Account::CreditCard.new(
      name: "Test Credit Card",
      due_day: 15,
      statement_day: 1,
      credit_limit: 5000,
      organization: organizations(:lazaro_personal)
    )

    assert credit_card.valid?
  end

  test "should validate credit_limit presence for credit card" do
    credit_card = Account::CreditCard.new(name: "Test Credit Card", organization: organizations(:lazaro_personal))

    credit_card.valid?

    assert_includes credit_card.errors[:credit_limit], "can't be blank"
  end

  test "should validate credit_limit numericality for credit card" do
    credit_card = Account::CreditCard.new(name: "Test Credit Card", organization: organizations(:lazaro_personal))
    credit_card.credit_limit = "invalid"

    credit_card.valid?

    assert_includes credit_card.errors[:credit_limit], "must be greater than 0"
  end

  test "should validate credit_limit greater than 0 for credit card" do
    credit_card = Account::CreditCard.new(name: "Test Credit Card", organization: organizations(:lazaro_personal))
    credit_card.credit_limit = 0

    credit_card.valid?

    assert_includes credit_card.errors[:credit_limit], "must be greater than 0"
  end

  test "should validate credit_limit greater than 0 for negative values" do
    credit_card = Account::CreditCard.new(name: "Test Credit Card", organization: organizations(:lazaro_personal))
    credit_card.credit_limit = -100

    credit_card.valid?

    assert_includes credit_card.errors[:credit_limit], "must be greater than 0"
  end

  test "should validate valid credit card fields with credit_limit" do
    credit_card = Account::CreditCard.new(
      name: "Test Credit Card",
      due_day: 15,
      statement_day: 1,
      credit_limit: 5000,
      organization: organizations(:lazaro_personal)
    )

    assert credit_card.valid?
  end

  test "should get and set credit_limit for credit card" do
    credit_card = Account::CreditCard.new(name: "Test Credit Card", organization: organizations(:lazaro_personal))

    credit_card.credit_limit = 2500.50
    assert_equal 2500.50, credit_card.credit_limit
  end

  test "should get and set due_day for credit card" do
    credit_card = Account::CreditCard.new(name: "Test Credit Card", organization: organizations(:lazaro_personal))

    credit_card.due_day = 20
    assert_equal 20, credit_card.due_day
  end

  test "should get and set statement_day for credit card" do
    credit_card = Account::CreditCard.new(name: "Test Credit Card", organization: organizations(:lazaro_personal))

    credit_card.statement_day = 5
    assert_equal 5, credit_card.statement_day
  end

  # posted_balance= setter tests for credit card accounts (creditor behavior)
  test "should set initial balance for credit card account" do
    credit_card_account = Account::CreditCard.new(name: "Test Credit Card", organization: organizations(:lazaro_personal))

    credit_card_account.posted_balance = 2000

    assert_equal 0, credit_card_account.read_attribute(:debits)
    assert_equal 200000, credit_card_account.read_attribute(:credits)
  end

  test "should allow zero initial balance for credit card" do
    credit_card_account = Account::CreditCard.new(name: "Test Credit Card", organization: organizations(:lazaro_personal))

    credit_card_account.posted_balance = 0

    assert_equal 0, credit_card_account.read_attribute(:debits)
    assert_equal 0, credit_card_account.read_attribute(:credits)
  end

  test "should reject negative initial balance for credit card" do
    credit_card_account = Account::CreditCard.new(name: "Test Credit Card", organization: organizations(:lazaro_personal))

    assert_raises(ArgumentError, "Amount must be positive or zero") do
      credit_card_account.posted_balance = -100
    end
  end

  # Credit card specific date calculation tests
  test "should calculate next statement date" do
    credit_card = Account::CreditCard.new(
      name: "Test Credit Card",
      statement_day: 15,
      organization: organizations(:lazaro_personal)
    )

    next_statement = credit_card.next_statement_date
    assert next_statement.is_a?(Date)
    assert_equal 15, next_statement.day
    assert next_statement >= Date.today
  end

  test "should calculate next due date" do
    credit_card = Account::CreditCard.new(
      name: "Test Credit Card",
      statement_day: 15,
      due_day: 25,
      organization: organizations(:lazaro_personal)
    )

    next_due = credit_card.next_due_date
    assert next_due.is_a?(Date)
    assert_equal 25, next_due.day
    assert next_due >= Date.today
  end

  test "should handle statement day at end of month" do
    credit_card = Account::CreditCard.new(
      name: "Test Credit Card",
      statement_day: 31,
      organization: organizations(:lazaro_personal)
    )

    next_statement = credit_card.next_statement_date
    assert next_statement.is_a?(Date)
    # Should be the last day of the month
    assert_equal Date.today.end_of_month.day, next_statement.day
  end

  test "should handle due day at end of month" do
    credit_card = Account::CreditCard.new(
      name: "Test Credit Card",
      statement_day: 1,
      due_day: 31,
      organization: organizations(:lazaro_personal)
    )

    next_due = credit_card.next_due_date
    assert next_due.is_a?(Date)
    # Should be the last day of the month
    assert_equal Date.today.end_of_month.day, next_due.day
  end
end
