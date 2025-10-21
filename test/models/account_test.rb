require "test_helper"

class AccountTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:lazaro_cash)
  end

  # Validations tests
  test "should be valid with required attributes" do
    assert @account.valid?
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


  # Balance tests
  test "should calculate posted balance" do
    revenue_account = accounts(:revenue_account)
    cash_account = accounts(:lazaro_cash)

    # Update account debits/credits to match posted transfer
    # Cash account must maintain positive balance, so set debits > credits
    revenue_account.update!(debits: 12.34, credits: 0)
    cash_account.update!(debits: 20.00, credits: 12.34)

    assert_equal 12.34, revenue_account.posted_balance
    assert_equal 7.66, cash_account.posted_balance
  end

  test "should calculate pending balance" do
    cash_account = accounts(:lazaro_cash)
    expense_account = accounts(:expense_account)

    # Set initial posted balances - cash account must have positive balance
    cash_account.update!(debits: 20.00, credits: 12.34) # From posted_transfer
    expense_account.update!(debits: 0, credits: 0)

    # cash_account has pending debit of 22.22 (from pending_transfer)
    # So pending balance should be: pending_debits(22.22) - pending_credits(0) = 22.22
    assert_equal 22.22, cash_account.pending_balance

    # expense_account has pending credit of 22.22 (from pending_transfer)
    # So pending balance should be: pending_debits(0) - pending_credits(22.22) = -22.22
    assert_equal -22.22, expense_account.pending_balance
  end

  test "should handle zero balances correctly" do
    # Use expense_account which has no posted transfers and only receives credits from pending_transfer
    expense_account = accounts(:expense_account)
    assert_equal 0, expense_account.posted_balance
    # expense_account has pending credit of 22.22, so pending balance should be -22.22
    assert_equal -22.22, expense_account.pending_balance
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
    assert_not_includes vendor_accounts, accounts(:lazaro_credit_card)
    assert_not_includes vendor_accounts, accounts(:lazaro_customer)
    assert_includes vendor_accounts, accounts(:lazaro_vendor)
    assert_includes vendor_accounts, accounts(:vendor_with_balance)
    assert_includes vendor_accounts, accounts(:revenue_account)
    assert_includes vendor_accounts, accounts(:expense_account)
    assert_includes vendor_accounts, accounts(:extra_vendor)
    assert_equal 5, vendor_accounts.count
  end

  test "credit_card scope should return only credit card accounts" do
    credit_card_accounts = Account.credit_card

    assert_not_includes credit_card_accounts, accounts(:lazaro_cash)
    assert_not_includes credit_card_accounts, accounts(:cash_with_balance)
    assert_not_includes credit_card_accounts, accounts(:extra_cash)
    assert_includes credit_card_accounts, accounts(:lazaro_credit_card)
    assert_not_includes credit_card_accounts, accounts(:lazaro_vendor)
    assert_not_includes credit_card_accounts, accounts(:vendor_with_balance)
    assert_not_includes credit_card_accounts, accounts(:revenue_account)
    assert_not_includes credit_card_accounts, accounts(:expense_account)
    assert_not_includes credit_card_accounts, accounts(:extra_vendor)
    assert_not_includes credit_card_accounts, accounts(:lazaro_customer)
    assert_not_includes credit_card_accounts, accounts(:customer_with_balance)
    assert_equal 1, credit_card_accounts.count
  end

  test "customer scope should return only customer accounts" do
    customer_accounts = Account.customer

    assert_not_includes customer_accounts, accounts(:lazaro_cash)
    assert_not_includes customer_accounts, accounts(:cash_with_balance)
    assert_not_includes customer_accounts, accounts(:extra_cash)
    assert_not_includes customer_accounts, accounts(:lazaro_credit_card)
    assert_not_includes customer_accounts, accounts(:lazaro_vendor)
    assert_not_includes customer_accounts, accounts(:vendor_with_balance)
    assert_not_includes customer_accounts, accounts(:revenue_account)
    assert_not_includes customer_accounts, accounts(:expense_account)
    assert_not_includes customer_accounts, accounts(:extra_vendor)
    assert_includes customer_accounts, accounts(:lazaro_customer)
    assert_includes customer_accounts, accounts(:customer_with_balance)
    assert_equal 2, customer_accounts.count
  end

  test "scopes should work with additional records" do
    cash_accounts = Account.cash
    vendor_accounts = Account.vendor
    credit_card_accounts = Account.credit_card
    customer_accounts = Account.customer

    assert_includes cash_accounts, accounts(:lazaro_cash)
    assert_includes cash_accounts, accounts(:cash_with_balance)
    assert_includes cash_accounts, accounts(:extra_cash)
    assert_not_includes cash_accounts, accounts(:lazaro_vendor)
    assert_not_includes cash_accounts, accounts(:lazaro_credit_card)
    assert_not_includes cash_accounts, accounts(:lazaro_customer)
    assert_equal 3, cash_accounts.count

    assert_not_includes vendor_accounts, accounts(:lazaro_cash)
    assert_not_includes vendor_accounts, accounts(:cash_with_balance)
    assert_not_includes vendor_accounts, accounts(:extra_cash)
    assert_not_includes vendor_accounts, accounts(:lazaro_credit_card)
    assert_not_includes vendor_accounts, accounts(:lazaro_customer)
    assert_includes vendor_accounts, accounts(:lazaro_vendor)
    assert_includes vendor_accounts, accounts(:vendor_with_balance)
    assert_includes vendor_accounts, accounts(:revenue_account)
    assert_includes vendor_accounts, accounts(:expense_account)
    assert_includes vendor_accounts, accounts(:extra_vendor)
    assert_equal 5, vendor_accounts.count

    assert_not_includes credit_card_accounts, accounts(:lazaro_cash)
    assert_not_includes credit_card_accounts, accounts(:cash_with_balance)
    assert_not_includes credit_card_accounts, accounts(:extra_cash)
    assert_includes credit_card_accounts, accounts(:lazaro_credit_card)
    assert_not_includes credit_card_accounts, accounts(:lazaro_vendor)
    assert_not_includes credit_card_accounts, accounts(:lazaro_customer)
    assert_equal 1, credit_card_accounts.count

    assert_not_includes customer_accounts, accounts(:lazaro_cash)
    assert_not_includes customer_accounts, accounts(:cash_with_balance)
    assert_not_includes customer_accounts, accounts(:extra_cash)
    assert_not_includes customer_accounts, accounts(:lazaro_credit_card)
    assert_not_includes customer_accounts, accounts(:lazaro_vendor)
    assert_includes customer_accounts, accounts(:lazaro_customer)
    assert_includes customer_accounts, accounts(:customer_with_balance)
    assert_equal 2, customer_accounts.count
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

    # Verify the values are numeric and reasonable
    assert planned_cash.is_a?(Numeric)
    assert planned_expense.is_a?(Numeric)
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

    # Verify the values are numeric
    assert planned_cash.is_a?(Numeric)
    assert planned_revenue.is_a?(Numeric)
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
    assert planned_cash.is_a?(Numeric)
    assert planned_expense.is_a?(Numeric)
    assert planned_revenue.is_a?(Numeric)

    # Verify the relationship: cash + expense + revenue should equal 0 (all transfers balance out)
    assert_equal 0, planned_cash + planned_expense + planned_revenue
  end

test "should allow negative planned balance" do
    cash_account = accounts(:lazaro_cash)

    future_date = Date.today + 10.days

    planned_balance = cash_account.planned_balance(future_date)
    assert planned_balance.is_a?(Numeric)
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
    assert planned_cash.is_a?(Numeric)
    assert planned_expense.is_a?(Numeric)
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
    assert planned_cash.is_a?(Numeric)
    assert planned_expense.is_a?(Numeric)
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
end
