require "test_helper"

class Account::CreditorTest < ActiveSupport::TestCase
  setup do
    @credit_card = accounts(:lazaro_credit_card)
    @customer = accounts(:lazaro_customer)
  end

  test "should include creditor concern in credit card accounts" do
    assert @credit_card.class.included_modules.include?(Account::Creditor)
  end

  test "should include creditor concern in customer accounts" do
    assert @customer.class.included_modules.include?(Account::Creditor)
  end

  # Balance calculation tests for creditor behavior
  test "should calculate posted balance as credits minus debits for credit card" do
    @credit_card.update!(debits: 200, credits: 1000)
    assert_equal 800, @credit_card.posted_balance
  end

  test "should calculate posted balance as credits minus debits for customer" do
    @customer.update!(debits: 200, credits: 1000)
    assert_equal 800, @customer.posted_balance
  end

  test "should handle zero balance for creditor accounts" do
    @credit_card.update!(debits: 1000, credits: 1000)
    assert_equal 0, @credit_card.posted_balance
  end

  test "should prevent negative posted balance for creditor accounts" do
    @credit_card.debits = 1000
    @credit_card.credits = 500

    assert_not @credit_card.valid?
    assert_includes @credit_card.errors[:base], "Creditor account cannot have credits less than debits"
  end

  test "should prevent negative posted balance for customer accounts" do
    @customer.debits = 1000
    @customer.credits = 500

    assert_not @customer.valid?
    assert_includes @customer.errors[:base], "Creditor account cannot have credits less than debits"
  end

# Pending balance tests for creditor behavior
test "should calculate pending balance as pending_credits minus pending_debits" do
    # Create pending transfers for testing
    cash_account = accounts(:lazaro_checking)

    # Create a pending transfer from cash to credit card (credit card gets credit)
    pending_transfer = Transfer.create!(
      debit_account: cash_account,
      credit_account: @credit_card,
      amount: 100,
      pending_on: Date.today,
      state: "pending"
    )

    # Credit card should have positive pending balance (more credits than debits)
    assert_equal 100, @credit_card.pending_balance
  end

  # Planned balance tests for creditor behavior
  test "should calculate planned balance correctly for creditor accounts" do
    future_date = Date.today + 30.days

    planned_balance = @credit_card.planned_balance(future_date)
    assert planned_balance.is_a?(Numeric)
  end

  # posted_balance= setter tests for creditor accounts
  test "should set initial balance by setting credits for creditor accounts" do
    new_credit_card = Account::CreditCard.new(name: "Test Credit Card", organization: organizations(:lazaro_personal))

    new_credit_card.posted_balance = 2000

    assert_equal 0, new_credit_card.debits
    assert_equal 2000.00, new_credit_card.credits
  end

  test "should set initial balance by setting credits for customer accounts" do
    new_customer = Account::Customer.new(name: "Test Customer", organization: organizations(:lazaro_personal))

    new_customer.posted_balance = 1500

    assert_equal 0, new_customer.debits
    assert_equal 1500.00, new_customer.credits
  end

  test "should handle zero initial balance for creditor accounts" do
    new_credit_card = Account::CreditCard.new(name: "Test Credit Card", organization: organizations(:lazaro_personal))

    new_credit_card.posted_balance = 0

    assert_equal 0, new_credit_card.debits
    assert_equal 0, new_credit_card.credits
  end

  test "should reject negative initial balance for creditor accounts" do
    new_credit_card = Account::CreditCard.new(name: "Test Credit Card", organization: organizations(:lazaro_personal))

    assert_raises(ArgumentError, "Amount must be positive or zero") do
      new_credit_card.posted_balance = -100
    end
  end

# Validation tests specific to creditor behavior
test "should validate credits greater than or equal to debits on balance change" do
    # Create a new credit card with invalid balance
    new_credit_card = Account::CreditCard.new(
      name: "Test Credit Card",
      due_day: 15,
      statement_day: 1,
      credit_limit: 5000,
      organization: organizations(:lazaro_personal),
      debits: 1500,  # More debits than credits - should be invalid
      credits: 1000
    )

    assert_not new_credit_card.valid?
    assert_includes new_credit_card.errors[:base], "Creditor account cannot have credits less than debits"
  end

  test "should not validate balance when debits and credits unchanged" do
    @credit_card.update!(debits: 500, credits: 1000)
    assert @credit_card.valid?

    # Update unrelated field - should still be valid
    @credit_card.name = "New Name"
    assert @credit_card.valid?
  end

  test "should allow equal debits and credits" do
    @credit_card.update!(debits: 1000, credits: 1000)
    assert @credit_card.valid?
    assert_equal 0, @credit_card.posted_balance
  end
end
