require "test_helper"

class Account::VendorTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:lazaro_vendor)
  end

  test "should be valid with required attributes" do
    assert @account.valid?
  end

  test "should be vendor account" do
    assert @account.vendor?
    assert_not @account.cash?
    assert_not @account.credit_card?
    assert_not @account.customer?
  end

  test "should have correct kind" do
    assert_equal "Account::Vendor", @account.kind
  end

  # Vendor account balance validation tests (debtor behavior)
  test "should allow positive posted balance for vendor account" do
    @account.update!(debits: 1000, credits: 500)
    assert @account.valid?
    assert_equal 500, @account.posted_balance
  end

  test "should allow zero posted balance for vendor account" do
    @account.update!(debits: 1000, credits: 1000)
    assert @account.valid?
    assert_equal 0, @account.posted_balance
  end

  test "should allow negative posted balance for vendor account" do
    @account.update!(debits: 500, credits: 1000)
    assert @account.valid?
    assert_equal -500, @account.posted_balance
  end

  test "should not validate balance when debits and credits unchanged" do
    # Start with valid state
    @account.update!(debits: 1000, credits: 500)
    assert @account.valid?

    # Update unrelated field - should still be valid
    @account.name = "New Name"
    assert @account.valid?
  end

  # posted_balance= setter tests for vendor accounts
  test "should set initial balance for vendor account" do
    vendor_account = Account::Vendor.new(name: "Test Vendor", organization: organizations(:lazaro_personal))

    vendor_account.posted_balance = 500

    assert_equal 500.00, vendor_account.debits
    assert_equal 0, vendor_account.credits
  end

  test "should allow zero initial balance" do
    vendor_account = Account::Vendor.new(name: "Test Vendor", organization: organizations(:lazaro_personal))

    vendor_account.posted_balance = 0

    assert_equal 0, vendor_account.debits
    assert_equal 0, vendor_account.credits
  end

  test "should reject negative initial balance" do
    vendor_account = Account::Vendor.new(name: "Test Vendor", organization: organizations(:lazaro_personal))

    assert_raises(ArgumentError, "Amount must be positive or zero") do
      vendor_account.posted_balance = -100
    end
  end

  test "should work with integer amounts" do
    vendor_account = Account::Vendor.new(name: "Test Vendor", organization: organizations(:lazaro_personal))

    vendor_account.posted_balance = 12345

    assert_equal 12345.00, vendor_account.debits
  end

  test "should work with float amounts that are whole numbers" do
    vendor_account = Account::Vendor.new(name: "Test Vendor", organization: organizations(:lazaro_personal))

    vendor_account.posted_balance = 1000.0

    assert_equal 1000.00, vendor_account.debits
  end

  test "should preserve existing balance when setting to same amount" do
    original_debits = @account.debits

    @account.posted_balance = original_debits

    assert_equal original_debits, @account.debits
  end

  test "should override existing balance when setting new amount" do
    @account.posted_balance = 9999

    assert_equal 9999.00, @account.debits
  end

  test "should handle string input for posted_balance" do
    vendor_account = Account::Vendor.new(name: "Test Vendor", organization: organizations(:lazaro_personal))

    vendor_account.posted_balance = "1500.50"

    assert_equal 1500.50, vendor_account.debits
  end

  # Vendor accounts should not have credit card specific fields
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
