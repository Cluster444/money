require "test_helper"

class Account::CashTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:lazaro_checking)
  end

  test "should be valid with required attributes" do
    assert @account.valid?
  end

  test "should be cash account" do
    assert @account.cash?
    assert_not @account.credit_card?
    assert_not @account.vendor?
    assert_not @account.customer?
  end

  test "should have correct kind" do
    assert_equal "Account::Cash", @account.kind
  end

  # Cash account balance validation tests (debtor behavior)
  test "should allow positive posted balance for cash account" do
    @account.update!(debits: 20.00, credits: 10.00)
    assert @account.valid?
    assert_equal 10.00, @account.posted_balance
  end

  test "should allow zero posted balance for cash account" do
    @account.update!(debits: 1000, credits: 1000)
    assert @account.valid?
    assert_equal 0, @account.posted_balance
  end

  test "should prevent negative posted balance for cash account" do
    @account.debits = 500
    @account.credits = 1000

    assert_not @account.valid?
    assert_includes @account.errors[:base], "Cash account cannot have a negative posted balance"
  end

  test "should not validate balance when debits and credits unchanged" do
    # Start with valid state
    @account.update!(debits: 1000, credits: 500)
    assert @account.valid?

    # Update unrelated field - should still be valid
    @account.name = "New Name"
    assert @account.valid?
  end

  # posted_balance= setter tests for cash accounts
  test "should set initial balance for cash account" do
    cash_account = Account::Cash.new(name: "Test Cash", organization: organizations(:lazaro_personal))

    cash_account.posted_balance = 1000

    assert_equal 100000, cash_account.read_attribute(:debits)
    assert_equal 0, cash_account.read_attribute(:credits)
  end

  test "should allow zero initial balance" do
    cash_account = Account::Cash.new(name: "Test Cash", organization: organizations(:lazaro_personal))

    cash_account.posted_balance = 0

    assert_equal 0, cash_account.read_attribute(:debits)
    assert_equal 0, cash_account.read_attribute(:credits)
  end

  test "should reject negative initial balance" do
    cash_account = Account::Cash.new(name: "Test Cash", organization: organizations(:lazaro_personal))

    assert_raises(ArgumentError, "Amount must be positive or zero") do
      cash_account.posted_balance = -100
    end
  end

  test "should work with integer amounts" do
    cash_account = Account::Cash.new(name: "Test Cash", organization: organizations(:lazaro_personal))

    cash_account.posted_balance = 12345

    assert_equal 1234500, cash_account.read_attribute(:debits)
  end

  test "should work with float amounts that are whole numbers" do
    cash_account = Account::Cash.new(name: "Test Cash", organization: organizations(:lazaro_personal))

    cash_account.posted_balance = 1000.0

    assert_equal 100000, cash_account.read_attribute(:debits)
  end

  test "should preserve existing balance when setting to same amount" do
    original_debits = @account.debits

    @account.posted_balance = original_debits

    assert_equal original_debits, @account.debits
  end

  test "should override existing balance when setting new amount" do
    @account.posted_balance = 9999

    assert_equal 999900, @account.read_attribute(:debits)
  end

  test "should handle string input for posted_balance" do
    cash_account = Account::Cash.new(name: "Test Cash", organization: organizations(:lazaro_personal))

    cash_account.posted_balance = "1500.50"

    assert_equal 150050, cash_account.read_attribute(:debits)
  end

  # Cash accounts should not have credit card specific fields
  test "should return nil for credit_limit" do
    assert_nil @account.credit_limit
  end

  test "should not validate credit card fields" do
    @account.valid?
    assert_not_includes @account.errors[:due_day], "can't be blank"
    assert_not_includes @account.errors[:statement_day], "can't be blank"
    assert_not_includes @account.errors[:credit_limit], "can't be blank"
  end
end
