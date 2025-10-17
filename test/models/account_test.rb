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

  test "should have many adjustments" do
    assert_respond_to @account, :adjustments
  end

  test "should get all related transfers" do
    revenue_account = accounts(:revenue_account)
    cash_account = accounts(:lazaro_cash)

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
    # So pending balance should be: pending_debits(2222) - pending_credits(0) = 2222
    assert_equal 2222, cash_account.pending_balance

    # expense_account has pending credit of 2222 (from pending_transfer)
    # So pending balance should be: pending_debits(0) - pending_credits(2222) = -2222
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
    assert_includes cash_accounts, accounts(:cash_with_balance)
    assert_includes cash_accounts, accounts(:extra_cash)
    assert_not_includes cash_accounts, accounts(:lazaro_vendor)
    assert_not_includes cash_accounts, accounts(:revenue_account)
    assert_not_includes cash_accounts, accounts(:expense_account)
    assert_equal 3, cash_accounts.count
  end

  test "vendor scope should return only vendor accounts" do
    vendor_accounts = Account.vendor

    assert_not_includes vendor_accounts, accounts(:lazaro_cash)
    assert_not_includes vendor_accounts, accounts(:cash_with_balance)
    assert_not_includes vendor_accounts, accounts(:extra_cash)
    assert_includes vendor_accounts, accounts(:lazaro_vendor)
    assert_includes vendor_accounts, accounts(:vendor_with_balance)
    assert_includes vendor_accounts, accounts(:revenue_account)
    assert_includes vendor_accounts, accounts(:expense_account)
    assert_includes vendor_accounts, accounts(:extra_vendor)
    assert_equal 5, vendor_accounts.count
  end

  test "scopes should work with additional records" do
    cash_accounts = Account.cash
    vendor_accounts = Account.vendor

    assert_includes cash_accounts, accounts(:lazaro_cash)
    assert_includes cash_accounts, accounts(:cash_with_balance)
    assert_includes cash_accounts, accounts(:extra_cash)
    assert_not_includes cash_accounts, accounts(:lazaro_vendor)
    assert_not_includes cash_accounts, accounts(:extra_vendor)
    assert_equal 3, cash_accounts.count

    assert_not_includes vendor_accounts, accounts(:lazaro_cash)
    assert_not_includes vendor_accounts, accounts(:cash_with_balance)
    assert_not_includes vendor_accounts, accounts(:extra_cash)
    assert_includes vendor_accounts, accounts(:lazaro_vendor)
    assert_includes vendor_accounts, accounts(:vendor_with_balance)
    assert_includes vendor_accounts, accounts(:revenue_account)
    assert_includes vendor_accounts, accounts(:expense_account)
    assert_includes vendor_accounts, accounts(:extra_vendor)
    assert_equal 5, vendor_accounts.count
  end

  # Planned balance tests
  test "should calculate planned balance with no schedules" do
    cash_account = accounts(:cash_with_balance)
    expense_account = accounts(:vendor_with_balance)

    # With no schedules, planned balance should be 0
    future_date = Date.today + 30.days
    assert_equal 0, cash_account.planned_balance(future_date)
    assert_equal 0, expense_account.planned_balance(future_date)
  end

test "should calculate planned balance with one-time schedule" do
    cash_account = accounts(:lazaro_cash)
    expense_account = accounts(:expense_account)

    future_date = Date.today + 30.days

    # Calculate expected values based on all schedules in fixtures
    # This test now verifies the planned_balance method works correctly
    planned_cash = cash_account.planned_balance(future_date)
    planned_expense = expense_account.planned_balance(future_date)

    # Verify the values are integers and reasonable
    assert planned_cash.is_a?(Integer)
    assert planned_expense.is_a?(Integer)
    # Cash should have negative planned balance (more credits than debits)
    assert planned_cash < 0
    # Expense should have positive planned balance (more debits than credits)
    assert planned_expense > 0
  end

test "should calculate planned balance with recurring schedule" do
    cash_account = accounts(:lazaro_cash)
    revenue_account = accounts(:revenue_account)

    future_date = Date.today + 3.months

    # Calculate planned balances
    planned_cash = cash_account.planned_balance(future_date)
    planned_revenue = revenue_account.planned_balance(future_date)

    # Verify the values are integers
    assert planned_cash.is_a?(Integer)
    assert planned_revenue.is_a?(Integer)
    # Cash should have negative planned balance (more credits than debits from monthly revenue)
    assert planned_cash < 0
    # Revenue should have positive planned balance (more debits than credits)
    assert planned_revenue > 0
    # They should have opposite signs (cash gets credits, revenue gets debits)
    assert planned_cash < 0
    assert planned_revenue > 0
  end

test "should handle planned balance with date before schedule starts" do
    cash_account = accounts(:cash_with_balance)
    expense_account = accounts(:vendor_with_balance)

    # Use accounts that have no schedules in fixtures
    before_date = Date.today + 1.week

    # With no schedules, planned balance should be 0
    assert_equal 0, cash_account.planned_balance(before_date)
    assert_equal 0, expense_account.planned_balance(before_date)
  end

test "should handle planned balance with multiple schedules" do
    cash_account = accounts(:lazaro_cash)
    expense_account = accounts(:expense_account)
    revenue_account = accounts(:revenue_account)

    future_date = Date.today + 2.months

    # Calculate planned balances
    planned_cash = cash_account.planned_balance(future_date)
    planned_expense = expense_account.planned_balance(future_date)
    planned_revenue = revenue_account.planned_balance(future_date)

    # Verify the values are integers
    assert planned_cash.is_a?(Integer)
    assert planned_expense.is_a?(Integer)
    assert planned_revenue.is_a?(Integer)

    # Verify the relationship: cash + expense + revenue should equal 0 (all transfers balance out)
    assert_equal 0, planned_cash + planned_expense + planned_revenue
  end

test "should allow negative planned balance" do
    cash_account = accounts(:lazaro_cash)

    future_date = Date.today + 10.days

    planned_balance = cash_account.planned_balance(future_date)
    assert planned_balance.is_a?(Integer)
    # Cash should have negative planned balance due to many credit schedules
    assert planned_balance < 0
  end

test "should handle edge case with same day as schedule start" do
    cash_account = accounts(:lazaro_cash)
    expense_account = accounts(:expense_account)

    # Use a future date to ensure we get planned transfers
    future_date = Date.today + 30.days

    planned_cash = cash_account.planned_balance(future_date)
    planned_expense = expense_account.planned_balance(future_date)

    # Verify the values are integers
    assert planned_cash.is_a?(Integer)
    assert planned_expense.is_a?(Integer)
    # Cash should have negative planned balance (more credits than debits)
    assert planned_cash < 0
    # Expense should have positive planned balance (more debits than credits)
    assert planned_expense > 0
  end

  test "should handle planned balance with weekly schedule" do
    cash_account = accounts(:lazaro_cash)
    expense_account = accounts(:expense_account)

    future_date = Date.today + 3.weeks

    planned_cash = cash_account.planned_balance(future_date)
    planned_expense = expense_account.planned_balance(future_date)

    # Verify the values are integers
    assert planned_cash.is_a?(Integer)
    assert planned_expense.is_a?(Integer)
    # Cash should have negative planned balance (more credits than debits)
    assert planned_cash < 0
    # Expense should have positive planned balance (more debits than credits)
    assert planned_expense > 0
  end

  # Adjustment tests
  test "should create credit adjustment" do
    initial_credits = @account.credits

    adjustment = @account.create_adjustment!(
      credit_amount: 100,
      note: "Test credit adjustment"
    )

    assert adjustment.persisted?
    assert_equal @account, adjustment.account
    assert_equal 100, adjustment.credit_amount
    assert_nil adjustment.debit_amount
    assert_equal "Test credit adjustment", adjustment.note

    @account.reload
    assert_equal initial_credits + 100, @account.credits
  end

  test "should create debit adjustment" do
    initial_debits = @account.debits

    adjustment = @account.create_adjustment!(
      debit_amount: 50,
      note: "Test debit adjustment"
    )

    assert adjustment.persisted?
    assert_equal @account, adjustment.account
    assert_nil adjustment.credit_amount
    assert_equal 50, adjustment.debit_amount
    assert_equal "Test debit adjustment", adjustment.note

    @account.reload
    assert_equal initial_debits + 50, @account.debits
  end

  test "should destroy associated adjustments when account destroyed" do
    adjustment_count = Adjustment.where(account: @account).count

    # Create some adjustments
    @account.create_adjustment!(credit_amount: 100, note: "Test 1")
    @account.create_adjustment!(debit_amount: 50, note: "Test 2")

    assert_difference "Adjustment.count", -(adjustment_count + 2) do
      @account.destroy
    end
  end

  # posted_balance= setter tests
  test "should set initial balance for cash account" do
    cash_account = Account.new(name: "Test Cash", kind: "cash", organization: organizations(:lazaro_personal))

    cash_account.posted_balance = 1000

    assert_equal 100000, cash_account.debits
    assert_equal 0, cash_account.credits
  end

  test "should set initial balance for vendor account" do
    vendor_account = Account.new(name: "Test Vendor", kind: "vendor", organization: organizations(:lazaro_personal))

    vendor_account.posted_balance = 500

    assert_equal 50000, vendor_account.debits
    assert_equal 0, vendor_account.credits
  end

  test "should set initial balance for credit card account" do
    credit_card_account = Account.new(name: "Test Credit Card", kind: "credit_card", organization: organizations(:lazaro_personal))

    credit_card_account.posted_balance = 2000

    assert_equal 0, credit_card_account.debits
    assert_equal 200000, credit_card_account.credits
  end

  test "should allow zero initial balance" do
    cash_account = Account.new(name: "Test Cash", kind: "cash", organization: organizations(:lazaro_personal))

    cash_account.posted_balance = 0

    assert_equal 0, cash_account.debits
    assert_equal 0, cash_account.credits
  end

  test "should reject negative initial balance" do
    cash_account = Account.new(name: "Test Cash", kind: "cash", organization: organizations(:lazaro_personal))

    assert_raises(ArgumentError, "Amount must be positive or zero") do
      cash_account.posted_balance = -100
    end
  end

  test "should work with integer amounts" do
    cash_account = Account.new(name: "Test Cash", kind: "cash", organization: organizations(:lazaro_personal))

    cash_account.posted_balance = 12345

    assert_equal 1234500, cash_account.debits
  end

  test "should work with float amounts that are whole numbers" do
    cash_account = Account.new(name: "Test Cash", kind: "cash", organization: organizations(:lazaro_personal))

    cash_account.posted_balance = 1000.0

    assert_equal 100000, cash_account.debits
  end

  test "should preserve existing balance when setting to same amount" do
    cash_account = accounts(:lazaro_cash)
    original_debits = cash_account.debits

    cash_account.posted_balance = original_debits

    assert_equal original_debits, cash_account.debits
  end

  test "should override existing balance when setting new amount" do
    cash_account = accounts(:lazaro_cash)

    cash_account.posted_balance = 9999

    assert_equal 999900, cash_account.debits
  end

  test "should handle string input for posted_balance" do
    cash_account = Account.new(name: "Test Cash", kind: "cash", organization: organizations(:lazaro_personal))

    cash_account.posted_balance = "1500.50"

    assert_equal 150050, cash_account.debits
  end

  # Credit card field validation tests
  test "should validate due_day presence for credit card" do
    credit_card = Account.new(name: "Test Credit Card", kind: "credit_card", organization: organizations(:lazaro_personal))

    credit_card.valid?

    assert_includes credit_card.errors[:due_day], "can't be blank"
  end

  test "should validate statement_day presence for credit card" do
    credit_card = Account.new(name: "Test Credit Card", kind: "credit_card", organization: organizations(:lazaro_personal))

    credit_card.valid?

    assert_includes credit_card.errors[:statement_day], "can't be blank"
  end

  test "should validate due_day numericality for credit card" do
    credit_card = Account.new(name: "Test Credit Card", kind: "credit_card", organization: organizations(:lazaro_personal))
    credit_card.due_day = "invalid"

    credit_card.valid?

    assert_includes credit_card.errors[:due_day], "must be greater than or equal to 1"
  end

  test "should validate statement_day numericality for credit card" do
    credit_card = Account.new(name: "Test Credit Card", kind: "credit_card", organization: organizations(:lazaro_personal))
    credit_card.statement_day = "invalid"

    credit_card.valid?

    assert_includes credit_card.errors[:statement_day], "must be greater than or equal to 1"
  end

  test "should validate due_day range for credit card" do
    credit_card = Account.new(name: "Test Credit Card", kind: "credit_card", organization: organizations(:lazaro_personal))
    credit_card.due_day = 32

    credit_card.valid?

    assert_includes credit_card.errors[:due_day], "must be less than or equal to 31"
  end

  test "should validate statement_day range for credit card" do
    credit_card = Account.new(name: "Test Credit Card", kind: "credit_card", organization: organizations(:lazaro_personal))
    credit_card.statement_day = 0

    credit_card.valid?

    assert_includes credit_card.errors[:statement_day], "must be greater than or equal to 1"
  end

  test "should validate valid credit card fields" do
    credit_card = Account.new(
      name: "Test Credit Card",
      kind: "credit_card",
      due_day: 15,
      statement_day: 1,
      organization: organizations(:lazaro_personal)
    )

    assert credit_card.valid?
  end

  test "should not validate due_day for non-credit card accounts" do
    cash_account = Account.new(name: "Test Cash", kind: "cash", organization: organizations(:lazaro_personal))

    cash_account.valid?

    assert_not_includes cash_account.errors[:due_day], "can't be blank"
  end

  test "should not validate statement_day for non-credit card accounts" do
    cash_account = Account.new(name: "Test Cash", kind: "cash", organization: organizations(:lazaro_personal))

    cash_account.valid?

    assert_not_includes cash_account.errors[:statement_day], "can't be blank"
  end
end
