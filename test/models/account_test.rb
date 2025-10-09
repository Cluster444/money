require "test_helper"

class AccountTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:lazaro_cash)
  end

  # Validations tests
  test "should be valid with required attributes" do
    assert @account.valid?
  end

  test "should require kind" do
    @account.kind = nil
    assert_not @account.valid?
    assert_includes @account.errors[:kind], "can't be blank"
  end

  test "should require valid kind" do
    assert_raises(ArgumentError) do
      @account.kind = "invalid_kind"
    end
  end

  test "should accept valid kinds" do
    %w[cash vendor].each do |kind|
      @account.kind = kind
      assert @account.valid?, "Kind #{kind} should be valid"
    end
  end

  test "should require name" do
    @account.name = nil
    assert_not @account.valid?
    assert_includes @account.errors[:name], "can't be blank"
  end

  # Association tests
  test "should have many debit transfers" do
    assert_respond_to @account, :debit_transfers
  end

  test "should have many credit transfers" do
    assert_respond_to @account, :credit_transfers
  end

  test "should have many debit schedules" do
    assert_respond_to @account, :debit_schedules
  end

  test "should have many credit schedules" do
    assert_respond_to @account, :credit_schedules
  end

  test "should get all related transfers" do
    revenue_account = accounts(:revenue_account)
    cash_account = accounts(:lazaro_cash)

    # Create additional transfers for testing
    Transfer.create!(debit_account: revenue_account, credit_account: cash_account,
                    amount: 100, pending_on: Date.today, state: "pending")

    transfers = revenue_account.transfers
    assert transfers.count >= 1
    assert transfers.all? { |t| t.debit_account_id == revenue_account.id || t.credit_account_id == revenue_account.id }
  end

  test "should get all related schedules" do
    revenue_account = accounts(:revenue_account)
    schedules = revenue_account.schedules
    assert schedules.count >= 1
    assert schedules.all? { |s| s.debit_account_id == revenue_account.id || s.credit_account_id == revenue_account.id }
  end

  # Deletion tests
  test "should destroy associated transfers when account destroyed" do
    revenue_account = accounts(:revenue_account)
    transfer_count = Transfer.where("debit_account_id = ? OR credit_account_id = ?", revenue_account.id, revenue_account.id).count

    assert_difference "Transfer.count", -transfer_count do
      revenue_account.destroy
    end
  end

  test "should destroy associated schedules when account destroyed" do
    revenue_account = accounts(:revenue_account)
    schedule_count = Schedule.where("debit_account_id = ? OR credit_account_id = ?", revenue_account.id, revenue_account.id).count

    assert_difference "Schedule.count", -schedule_count do
      revenue_account.destroy
    end
  end

  # Enum tests
  test "should define kind enum" do
    assert Account.kinds.key?("cash")
    assert Account.kinds.key?("vendor")
  end

  test "should have kind methods" do
    @account.cash!
    assert @account.cash?
    assert_not @account.vendor?

    @account.vendor!
    assert @account.vendor?
    assert_not @account.cash?
  end

  # Balance tests
  test "should calculate posted balance" do
    revenue_account = accounts(:revenue_account)
    cash_account = accounts(:lazaro_cash)

    # Update account debits/credits to match posted transfer
    # Cash account must maintain positive balance, so set debits > credits
    revenue_account.update!(debits: 1234, credits: 0)
    cash_account.update!(debits: 2000, credits: 1234)

    assert_equal 1234, revenue_account.posted_balance
    assert_equal 766, cash_account.posted_balance
  end

  test "should calculate pending balance" do
    cash_account = accounts(:lazaro_cash)
    expense_account = accounts(:expense_account)

    # Set initial posted balances - cash account must have positive balance
    cash_account.update!(debits: 2000, credits: 1234) # From posted_transfer
    expense_account.update!(debits: 0, credits: 0)

    # cash_account has pending debit of 2222 (from pending_transfer)
    # So pending balance should be: posted_balance(766) + pending_debits(2222) - pending_credits(0) = 2988
    assert_equal 2988, cash_account.pending_balance

    # expense_account has pending credit of 2222 (from pending_transfer)
    # So pending balance should be: posted_balance(0) + pending_debits(0) - pending_credits(2222) = -2222
    assert_equal -2222, expense_account.pending_balance
  end

  test "should handle zero balances correctly" do
    # Use expense_account which has no posted transfers and only receives credits from pending_transfer
    expense_account = accounts(:expense_account)
    assert_equal 0, expense_account.posted_balance
    # expense_account has pending credit of 2222, so pending balance should be -2222
    assert_equal -2222, expense_account.pending_balance
  end

  # Cash account balance validation tests
  test "should allow positive posted balance for cash account" do
    cash_account = accounts(:lazaro_cash)
    cash_account.update!(debits: 2000, credits: 1000)
    assert cash_account.valid?
    assert_equal 1000, cash_account.posted_balance
  end

  test "should allow zero posted balance for cash account" do
    cash_account = accounts(:lazaro_cash)
    cash_account.update!(debits: 1000, credits: 1000)
    assert cash_account.valid?
    assert_equal 0, cash_account.posted_balance
  end

  test "should prevent negative posted balance for cash account" do
    cash_account = accounts(:lazaro_cash)
    cash_account.debits = 500
    cash_account.credits = 1000

    assert_not cash_account.valid?
    assert_includes cash_account.errors[:base], "Cash account cannot have a negative posted balance"
  end

  test "should allow negative posted balance for vendor account" do
    vendor_account = accounts(:lazaro_vendor)
    vendor_account.update!(debits: 500, credits: 1000)
    assert vendor_account.valid?
    assert_equal -500, vendor_account.posted_balance
  end

  test "should not validate balance when debits and credits unchanged" do
    cash_account = accounts(:lazaro_cash)
    # Start with valid state
    cash_account.update!(debits: 1000, credits: 500)
    assert cash_account.valid?

    # Update unrelated field - should still be valid
    cash_account.name = "New Name"
    assert cash_account.valid?
  end

  # Scope tests
  test "cash scope should return only cash accounts" do
    cash_accounts = Account.cash

    assert_includes cash_accounts, accounts(:lazaro_cash)
    assert_not_includes cash_accounts, accounts(:lazaro_vendor)
    assert_not_includes cash_accounts, accounts(:revenue_account)
    assert_not_includes cash_accounts, accounts(:expense_account)
    assert_equal 1, cash_accounts.count
  end

  test "vendor scope should return only vendor accounts" do
    vendor_accounts = Account.vendor

    assert_not_includes vendor_accounts, accounts(:lazaro_cash)
    assert_includes vendor_accounts, accounts(:lazaro_vendor)
    assert_includes vendor_accounts, accounts(:revenue_account)
    assert_includes vendor_accounts, accounts(:expense_account)
    assert_equal 3, vendor_accounts.count
  end

  test "scopes should work with additional records" do
    # Create additional accounts to test with more records
    new_cash = Account.create!(
      kind: :cash,
      name: "New Cash Account",
      active: true,
      debits: 0,
      credits: 0,
      metadata: {},
      user: users(:lazaro_nixon),
      user: users(:lazaro_nixon)
    )

    new_vendor = Account.create!(
      kind: :vendor,
      name: "New Vendor Account",
      active: true,
      debits: 0,
      credits: 0,
      metadata: {},
      user: users(:lazaro_nixon),
      user: users(:lazaro_nixon)
    )

    cash_accounts = Account.cash
    vendor_accounts = Account.vendor

    assert_includes cash_accounts, accounts(:lazaro_cash)
    assert_includes cash_accounts, new_cash
    assert_not_includes cash_accounts, accounts(:lazaro_vendor)
    assert_not_includes cash_accounts, new_vendor
    assert_equal 2, cash_accounts.count

    assert_not_includes vendor_accounts, accounts(:lazaro_cash)
    assert_not_includes vendor_accounts, new_cash
    assert_includes vendor_accounts, accounts(:lazaro_vendor)
    assert_includes vendor_accounts, new_vendor
    assert_equal 4, vendor_accounts.count

    # Clean up
    new_cash.destroy
    new_vendor.destroy
  end

  # Planned balance tests
  test "should calculate planned balance with no schedules" do
    # Create fresh accounts without existing schedules
    cash_account = Account.create!(
      kind: :cash,
      name: "Test Cash Account",
      active: true,
      debits: 2000,
      credits: 1234,
      metadata: {},
      user: users(:lazaro_nixon)
    )

    expense_account = Account.create!(
      kind: :vendor,
      name: "Test Expense Account",
      active: true,
      debits: 0,
      credits: 0,
      metadata: {},
      user: users(:lazaro_nixon)
    )

    # Create pending transfer to match fixture behavior
    Transfer.create!(
      debit_account: cash_account,
      credit_account: expense_account,
      amount: 2222,
      pending_on: Date.yesterday,
      state: :pending
    )

    # With no schedules, planned balance should equal pending balance
    future_date = Date.today + 30.days
    assert_equal cash_account.pending_balance, cash_account.planned_balance(future_date)
    assert_equal expense_account.pending_balance, expense_account.planned_balance(future_date)

    # Clean up
    cash_account.destroy
    expense_account.destroy
  end

test "should calculate planned balance with one-time schedule" do
    # Create fresh accounts
    cash_account = Account.create!(
      kind: :cash,
      name: "Test Cash Account",
      active: true,
      debits: 2000,
      credits: 1234,
      metadata: {},
      user: users(:lazaro_nixon)
    )

    expense_account = Account.create!(
      kind: :vendor,
      name: "Test Expense Account",
      active: true,
      debits: 0,
      credits: 0,
      metadata: {},
      user: users(:lazaro_nixon)
    )

    # Create pending transfer to match fixture behavior
    Transfer.create!(
      debit_account: cash_account,
      credit_account: expense_account,
      amount: 2222,
      pending_on: Date.yesterday,
      state: :pending
    )

    # Create one-time schedule: cash -> expense for $500
    schedule = Schedule.create!(
      name: "One-time payment",
      amount: 500,
      starts_on: Date.today + 10.days,
      debit_account: cash_account,
      credit_account: expense_account
    )

future_date = Date.today + 30.days

    # cash_account: pending_balance(2988) + planned_debits(500) - planned_credits(0) = 3488
    assert_equal 3488, cash_account.planned_balance(future_date)

    # expense_account: pending_balance(-2222) + planned_debits(0) - planned_credits(500) = -2722
    assert_equal -2722, expense_account.planned_balance(future_date)

    # Clean up
    cash_account.destroy
    expense_account.destroy
  end

test "should calculate planned balance with recurring schedule" do
    # Create fresh accounts
    cash_account = Account.create!(
      kind: :cash,
      name: "Test Cash Account",
      active: true,
      debits: 2000,
      credits: 1234,
      metadata: {},
      user: users(:lazaro_nixon)
    )

    expense_account = Account.create!(
      kind: :vendor,
      name: "Test Expense Account",
      active: true,
      debits: 0,
      credits: 0,
      metadata: {},
      user: users(:lazaro_nixon)
    )

    # Create pending transfer to match fixture behavior
    Transfer.create!(
      debit_account: cash_account,
      credit_account: expense_account,
      amount: 2222,
      pending_on: Date.yesterday,
      state: :pending
    )

    # Create monthly schedule: cash -> expense for $200, starting today, for 3 months
    schedule = Schedule.create!(
      name: "Monthly payment",
      amount: 200,
      starts_on: Date.today,
      period: "month",
      frequency: 1,
      ends_on: Date.today + 2.months,
      debit_account: cash_account,
      credit_account: expense_account
    )

    future_date = Date.today + 3.months

    # Should have 3 occurrences (today, +1 month, +2 months)
    # cash_account: pending_balance(2988) + planned_debits(600) - planned_credits(0) = 3588
    assert_equal 3588, cash_account.planned_balance(future_date)

    # expense_account: pending_balance(-2222) + planned_debits(0) - planned_credits(600) = -2822
    assert_equal -2822, expense_account.planned_balance(future_date)

    # Clean up
    cash_account.destroy
    expense_account.destroy
  end

test "should handle planned balance with date before schedule starts" do
    # Create fresh accounts
    cash_account = Account.create!(
      kind: :cash,
      name: "Test Cash Account",
      active: true,
      debits: 2000,
      credits: 1234,
      metadata: {},
      user: users(:lazaro_nixon)
    )

    expense_account = Account.create!(
      kind: :vendor,
      name: "Test Expense Account",
      active: true,
      debits: 0,
      credits: 0,
      metadata: {},
      user: users(:lazaro_nixon)
    )

    # Create pending transfer to match fixture behavior
    Transfer.create!(
      debit_account: cash_account,
      credit_account: expense_account,
      amount: 2222,
      pending_on: Date.yesterday,
      state: :pending
    )

    # Create schedule starting in the future
    schedule = Schedule.create!(
      name: "Future payment",
      amount: 300,
      starts_on: Date.today + 30.days,
      debit_account: cash_account,
      credit_account: expense_account
    )

    # Query date before schedule starts
    before_date = Date.today + 15.days

    # Should equal pending balance since no planned transfers yet
    assert_equal cash_account.pending_balance, cash_account.planned_balance(before_date)
    assert_equal expense_account.pending_balance, expense_account.planned_balance(before_date)

    # Clean up
    cash_account.destroy
    expense_account.destroy
  end

test "should handle planned balance with multiple schedules" do
    # Create fresh accounts
    cash_account = Account.create!(
      kind: :cash,
      name: "Test Cash Account",
      active: true,
      debits: 2000,
      credits: 1234,
      metadata: {},
      user: users(:lazaro_nixon)
    )

    expense_account = Account.create!(
      kind: :vendor,
      name: "Test Expense Account",
      active: true,
      debits: 0,
      credits: 0,
      metadata: {},
      user: users(:lazaro_nixon)
    )

    revenue_account = Account.create!(
      kind: :vendor,
      name: "Test Revenue Account",
      active: true,
      debits: 1234,
      credits: 0,
      metadata: {},
      user: users(:lazaro_nixon)
    )

    # Create pending transfer to match fixture behavior
    Transfer.create!(
      debit_account: cash_account,
      credit_account: expense_account,
      amount: 2222,
      pending_on: Date.yesterday,
      state: :pending
    )

    # Schedule 1: cash -> expense, $100 monthly for 2 months
    schedule1 = Schedule.create!(
      name: "Monthly expense",
      amount: 100,
      starts_on: Date.today,
      period: "month",
      frequency: 1,
      ends_on: Date.today + 1.month,
      debit_account: cash_account,
      credit_account: expense_account
    )

    # Schedule 2: revenue -> cash, $500 one-time
    schedule2 = Schedule.create!(
      name: "One-time income",
      amount: 500,
      starts_on: Date.today + 10.days,
      debit_account: revenue_account,
      credit_account: cash_account
    )

    future_date = Date.today + 2.months

    # cash_account: pending_balance(2988) + planned_debits(200) - planned_credits(500) = 2688
    assert_equal 2688, cash_account.planned_balance(future_date)

    # expense_account: pending_balance(-2222) + planned_debits(0) - planned_credits(200) = -2422
    assert_equal -2422, expense_account.planned_balance(future_date)

    # revenue_account: pending_balance(1234) + planned_debits(500) - planned_credits(0) = 1734
    assert_equal 1734, revenue_account.planned_balance(future_date)

    # Clean up
    cash_account.destroy
    expense_account.destroy
    revenue_account.destroy
  end

test "should allow negative planned balance" do
# Create fresh accounts
cash_account = Account.create!(
      kind: :cash,
      name: "Test Cash Account",
      active: true,
      debits: 2000,
      credits: 1234,
      metadata: {},
      user: users(:lazaro_nixon),
      user: users(:lazaro_nixon)
    )

    expense_account = Account.create!(
      kind: :vendor,
      name: "Test Expense Account",
      active: true,
      debits: 0,
      credits: 0,
      metadata: {},
      user: users(:lazaro_nixon)
    )

    # Create large scheduled payment where cash account gives money (will make balance negative)
    schedule = Schedule.create!(
      name: "Large payment",
      amount: 200,
      starts_on: Date.today + 5.days,
      debit_account: expense_account,  # expense receives money
      credit_account: cash_account      # cash gives money
    )

    future_date = Date.today + 10.days

    # Should be negative: posted_balance(0) + pending_debits(0) - pending_credits(0) + planned_debits(0) - planned_credits(200) = -200
    planned_balance = cash_account.planned_balance(future_date)
    assert_equal -200, planned_balance
    assert planned_balance.is_a?(Integer)

    # Clean up
    cash_account.destroy
    expense_account.destroy
  end

test "should handle edge case with same day as schedule start" do
    # Create fresh accounts
    cash_account = Account.create!(
      kind: :cash,
      name: "Test Cash Account",
      active: true,
      debits: 2000,
      credits: 1234,
      metadata: {},
      user: users(:lazaro_nixon)
    )

    expense_account = Account.create!(
      kind: :vendor,
      name: "Test Expense Account",
      active: true,
      debits: 0,
      credits: 0,
      metadata: {},
      user: users(:lazaro_nixon)
    )

    # Create pending transfer to match fixture behavior
    Transfer.create!(
      debit_account: cash_account,
      credit_account: expense_account,
      amount: 2222,
      pending_on: Date.yesterday,
      state: :pending
    )

    # Create schedule starting today
    schedule = Schedule.create!(
      name: "Today's payment",
      amount: 150,
      starts_on: Date.today,
      debit_account: cash_account,
      credit_account: expense_account
    )

    # Query for today
    today = Date.today

    # Should include the scheduled transfer
    # cash_account: pending_balance(2988) + planned_debits(150) - planned_credits(0) = 3138
    assert_equal 3138, cash_account.planned_balance(today)

    # expense_account: pending_balance(-2222) + planned_debits(0) - planned_credits(150) = -2372
    assert_equal -2372, expense_account.planned_balance(today)

    # Clean up
    cash_account.destroy
    expense_account.destroy
  end

test "should handle planned balance with weekly schedule" do
    # Create fresh accounts
    cash_account = Account.create!(
      kind: :cash,
      name: "Test Cash Account",
      active: true,
      debits: 2000,
      credits: 1234,
      metadata: {},
      user: users(:lazaro_nixon)
    )

    expense_account = Account.create!(
      kind: :vendor,
      name: "Test Expense Account",
      active: true,
      debits: 0,
      credits: 0,
      metadata: {},
      user: users(:lazaro_nixon)
    )

    # Create pending transfer to match fixture behavior
    Transfer.create!(
      debit_account: cash_account,
      credit_account: expense_account,
      amount: 2222,
      pending_on: Date.yesterday,
      state: :pending
    )

    # Create weekly schedule for 3 weeks
    schedule = Schedule.create!(
      name: "Weekly payment",
      amount: 50,
      starts_on: Date.today,
      period: "week",
      frequency: 1,
      ends_on: Date.today + 2.weeks,
      debit_account: cash_account,
      credit_account: expense_account
    )

    future_date = Date.today + 3.weeks

    # Should have 3 occurrences (today, +1 week, +2 weeks)
    # cash_account: pending_balance(2988) + planned_debits(150) - planned_credits(0) = 3138
    assert_equal 3138, cash_account.planned_balance(future_date)

    # expense_account: pending_balance(-2222) + planned_debits(0) - planned_credits(150) = -2372
    assert_equal -2372, expense_account.planned_balance(future_date)

    # Clean up
    cash_account.destroy
    expense_account.destroy
  end
end
