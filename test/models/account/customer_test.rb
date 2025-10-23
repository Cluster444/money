require "test_helper"

class Account::CustomerTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:lazaro_customer)
  end

  test "should be valid with required attributes" do
    assert @account.valid?
  end

  test "should be customer account" do
    assert @account.customer?
    assert_not @account.cash?
    assert_not @account.credit_card?
    assert_not @account.vendor?
  end

  test "should have correct kind" do
    assert_equal "Account::Customer", @account.kind
  end

  # Customer account balance validation tests (creditor behavior)
  test "should allow positive posted balance for customer account" do
    @account.update!(debits: 200, credits: 1000)
    assert @account.valid?
    assert_equal 800, @account.posted_balance
  end

  test "should allow zero posted balance for customer account" do
    @account.update!(debits: 1000, credits: 1000)
    assert @account.valid?
    assert_equal 0, @account.posted_balance
  end

  test "should prevent negative posted balance for customer account" do
    @account.debits = 1000
    @account.credits = 500

    assert_not @account.valid?
    assert_includes @account.errors[:base], "Creditor account cannot have credits less than debits"
  end

  test "should not validate balance when debits and credits unchanged" do
    # Start with valid state
    @account.update!(debits: 200, credits: 1000)
    assert @account.valid?

    # Update unrelated field - should still be valid
    @account.name = "New Name"
    assert @account.valid?
  end

  # posted_balance= setter tests for customer accounts
  test "should set initial balance for customer account" do
    customer_account = Account::Customer.new(name: "Test Customer", organization: organizations(:lazaro_personal))

    customer_account.posted_balance = 1000

    assert_equal 0, customer_account.debits
    assert_equal 1000.00, customer_account.credits
  end

  test "should allow zero initial balance" do
    customer_account = Account::Customer.new(name: "Test Customer", organization: organizations(:lazaro_personal))

    customer_account.posted_balance = 0

    assert_equal 0, customer_account.read_attribute(:debits)
    assert_equal 0, customer_account.read_attribute(:credits)
  end

  test "should reject negative initial balance" do
    customer_account = Account::Customer.new(name: "Test Customer", organization: organizations(:lazaro_personal))

    assert_raises(ArgumentError, "Amount must be positive or zero") do
      customer_account.posted_balance = -100
    end
  end

  test "should work with integer amounts" do
    customer_account = Account::Customer.new(name: "Test Customer", organization: organizations(:lazaro_personal))

    customer_account.posted_balance = 12345

    assert_equal 12345.00, customer_account.credits
  end

  test "should work with float amounts that are whole numbers" do
    customer_account = Account::Customer.new(name: "Test Customer", organization: organizations(:lazaro_personal))

    customer_account.posted_balance = 1000.0

    assert_equal 1000.00, customer_account.credits
  end

  test "should preserve existing balance when setting to same amount" do
    original_credits = @account.credits

    @account.posted_balance = original_credits

    assert_equal original_credits, @account.credits
  end

  test "should override existing balance when setting new amount" do
    @account.posted_balance = 9999

    assert_equal 9999.00, @account.credits
  end

  test "should handle string input for posted_balance" do
    customer_account = Account::Customer.new(name: "Test Customer", organization: organizations(:lazaro_personal))

    customer_account.posted_balance = "1500.50"

    assert_equal 1500.50, customer_account.credits
  end

  # Customer accounts should not have credit card specific fields
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
