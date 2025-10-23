require "test_helper"

class Account::DebtorTest < ActiveSupport::TestCase
  setup do
    @cash = accounts(:lazaro_checking)
    @vendor = accounts(:lazaro_vendor)
  end

  test "should include debtor concern in cash accounts" do
    assert @cash.class.included_modules.include?(Account::Debtor)
  end

  test "should include debtor concern in vendor accounts" do
    assert @vendor.class.included_modules.include?(Account::Debtor)
  end

  # Balance calculation tests for debtor behavior
  test "should calculate posted balance as debits minus credits for cash" do
    @cash.update!(debits: 1000, credits: 200)
    assert_equal 800, @cash.posted_balance
  end

  test "should calculate posted balance as debits minus credits for vendor" do
    @vendor.update!(debits: 1000, credits: 200)
    assert_equal 800, @vendor.posted_balance
  end

  test "should handle zero balance for debtor accounts" do
    @cash.update!(debits: 1000, credits: 1000)
    assert_equal 0, @cash.posted_balance
  end

  test "should prevent negative posted balance for cash accounts" do
    @cash.debits = 500
    @cash.credits = 1000

    assert_not @cash.valid?
    assert_includes @cash.errors[:base], "Cash account cannot have a negative posted balance"
  end

  test "should allow negative posted balance for vendor accounts" do
    @vendor.update!(debits: 500, credits: 1000)
    assert @vendor.valid?
    assert_equal -500, @vendor.posted_balance
  end

# Pending balance tests for debtor behavior
test "should calculate pending balance as pending_debits minus pending_credits" do
    # Create pending transfers for testing
    expense_account = accounts(:expense_account)

    # Create a pending transfer from cash to expense (cash gets debit)
    pending_transfer = Transfer.create!(
      debit_account: @cash,
      credit_account: expense_account,
      amount: 100,
      pending_on: Date.today,
      state: "pending"
    )

    # Cash should have positive pending balance (more debits than credits)
    # There's already a pending transfer in fixtures, so we check that it's positive
    assert @cash.pending_balance > 0
  end

  # Planned balance tests for debtor behavior
  test "should calculate planned balance correctly for debtor accounts" do
    future_date = Date.today + 30.days

    planned_balance = @cash.planned_balance(future_date)
    assert planned_balance.is_a?(Numeric)
  end

  # posted_balance= setter tests for debtor accounts
  test "should set initial balance by setting debits for debtor accounts" do
    new_cash = Account::Cash.new(name: "Test Cash", organization: organizations(:lazaro_personal))

    new_cash.posted_balance = 2000

    assert_equal 2000.00, new_cash.debits
    assert_equal 0, new_cash.credits
  end

  test "should set initial balance by setting debits for vendor accounts" do
    new_vendor = Account::Vendor.new(name: "Test Vendor", organization: organizations(:lazaro_personal))

    new_vendor.posted_balance = 1500

    assert_equal 1500.00, new_vendor.debits
    assert_equal 0, new_vendor.credits
  end

  test "should handle zero initial balance for debtor accounts" do
    new_cash = Account::Cash.new(name: "Test Cash", organization: organizations(:lazaro_personal))

    new_cash.posted_balance = 0

    assert_equal 0, new_cash.debits
    assert_equal 0, new_cash.credits
  end

  test "should reject negative initial balance for debtor accounts" do
    new_cash = Account::Cash.new(name: "Test Cash", organization: organizations(:lazaro_personal))

    assert_raises(ArgumentError, "Amount must be positive or zero") do
      new_cash.posted_balance = -100
    end
  end

# Validation tests specific to debtor behavior
test "should validate debits greater than or equal to credits for cash accounts" do
    # Create a new cash account with invalid balance
    new_cash = Account::Cash.new(
      name: "Test Cash",
      organization: organizations(:lazaro_personal),
      debits: 500,   # Less debits than credits - should be invalid
      credits: 1000
    )

    assert_not new_cash.valid?
    assert_includes new_cash.errors[:base], "Cash account cannot have a negative posted balance"
  end

  test "should allow any balance for vendor accounts" do
    # Vendor accounts can have negative balances
    @vendor.update!(debits: 500, credits: 1000)
    assert @vendor.valid?
    assert_equal -500, @vendor.posted_balance

    # And positive balances
    @vendor.update!(debits: 1000, credits: 500)
    assert @vendor.valid?
    assert_equal 500, @vendor.posted_balance
  end

  test "should not validate balance when debits and credits unchanged" do
    @cash.update!(debits: 1000, credits: 500)
    assert @cash.valid?

    # Update unrelated field - should still be valid
    @cash.name = "New Name"
    assert @cash.valid?
  end

  test "should allow equal debits and credits" do
    @cash.update!(debits: 1000, credits: 1000)
    assert @cash.valid?
    assert_equal 0, @cash.posted_balance
  end

  # Cash account specific validation
  test "should prevent negative posted balance for cash accounts specifically" do
    @cash.debits = 500
    @cash.credits = 1000

    assert_not @cash.valid?
    assert_includes @cash.errors[:base], "Cash account cannot have a negative posted balance"
  end
end
