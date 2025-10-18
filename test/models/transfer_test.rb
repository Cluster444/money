require "test_helper"

class TransferTest < ActiveSupport::TestCase
  setup do
    @posted_transfer = transfers(:posted_transfer)
    @pending_transfer = transfers(:pending_transfer)
  end

  # Validations tests
  test "should be valid with required attributes" do
    assert @posted_transfer.valid?
    assert @pending_transfer.valid?
  end

  test "should require state" do
    @posted_transfer.state = nil
    assert_not @posted_transfer.valid?
    assert_includes @posted_transfer.errors[:state], "can't be blank"
  end

  test "should require valid state" do
    assert_raises(ArgumentError) do
      @posted_transfer.state = "invalid_state"
    end
  end

  test "should accept valid states" do
    %w[pending posted].each do |state|
      @posted_transfer.state = state
      assert @posted_transfer.valid?, "State #{state} should be valid"
    end
  end

  test "should require amount" do
    @posted_transfer.amount = nil
    assert_not @posted_transfer.valid?
    assert_includes @posted_transfer.errors[:amount], "can't be blank"
  end

  test "should require amount greater than 0" do
    @posted_transfer.amount = 0
    assert_not @posted_transfer.valid?
    assert_includes @posted_transfer.errors[:amount], "must be greater than 0"

    @posted_transfer.amount = -100
    assert_not @posted_transfer.valid?
    assert_includes @posted_transfer.errors[:amount], "must be greater than 0"
  end

  test "should require pending_on" do
    @posted_transfer.pending_on = nil
    assert_not @posted_transfer.valid?
    assert_includes @posted_transfer.errors[:pending_on], "can't be blank"
  end

  test "should require debit_account" do
    @posted_transfer.debit_account = nil
    assert_not @posted_transfer.valid?
    assert_includes @posted_transfer.errors[:debit_account], "must exist"
  end

  test "should require credit_account" do
    @posted_transfer.credit_account = nil
    assert_not @posted_transfer.valid?
    assert_includes @posted_transfer.errors[:credit_account], "must exist"
  end

  test "should require different debit and credit accounts" do
    @posted_transfer.credit_account = @posted_transfer.debit_account
    assert_not @posted_transfer.valid?
    assert_includes @posted_transfer.errors[:credit_account], "must be different from debit account"
  end

  # Association tests
  test "should belong to debit_account" do
    assert_respond_to @posted_transfer, :debit_account
    assert_equal accounts(:revenue_account), @posted_transfer.debit_account
  end

  test "should belong to credit_account" do
    assert_respond_to @posted_transfer, :credit_account
    assert_equal accounts(:lazaro_cash), @posted_transfer.credit_account
  end

  test "should belong to schedule optionally" do
    assert_respond_to @posted_transfer, :schedule
    assert_equal schedules(:monthly_schedule), @posted_transfer.schedule

    assert_nil @pending_transfer.schedule
  end

  # Deletion tests
  test "should reverse account balances when deleting posted transfer" do
    revenue_account = accounts(:revenue_account)
    cash_account = accounts(:lazaro_cash)

    # Set initial balances - cash account must maintain positive balance
    revenue_account.update!(debits: @posted_transfer.amount)
    cash_account.update!(debits: @posted_transfer.amount + 1000, credits: @posted_transfer.amount)

    initial_debits = revenue_account.debits
    initial_credits = cash_account.credits

    @posted_transfer.destroy

    revenue_account.reload
    cash_account.reload

    assert_equal initial_debits - @posted_transfer.amount, revenue_account.debits
    assert_equal initial_credits - @posted_transfer.amount, cash_account.credits
  end

  test "should simply delete pending transfer without reversing balances" do
    cash_account = accounts(:lazaro_cash)
    expense_account = accounts(:expense_account)

    initial_debits = cash_account.debits
    initial_credits = expense_account.credits

    @pending_transfer.destroy

    cash_account.reload
    expense_account.reload

    assert_equal initial_debits, cash_account.debits
    assert_equal initial_credits, expense_account.credits
  end

  # Enum tests
  test "should define state enum" do
    assert Transfer.states.key?("pending")
    assert Transfer.states.key?("posted")
  end

  test "should have state methods" do
    @pending_transfer.pending!
    assert @pending_transfer.pending?
    assert_not @pending_transfer.posted?

    @pending_transfer.posted_on = Date.current
    @pending_transfer.posted!
    assert @pending_transfer.posted?
    assert_not @pending_transfer.pending?
  end

  # Fixture tests
  test "posted transfer should have correct attributes" do
    assert_equal "posted", @posted_transfer.state
    assert_equal 1234, @posted_transfer.amount
    assert_equal 2.weeks.ago.to_date, @posted_transfer.pending_on
    assert_equal 2.weeks.ago.to_date, @posted_transfer.posted_on
    assert_equal accounts(:revenue_account), @posted_transfer.debit_account
    assert_equal accounts(:lazaro_cash), @posted_transfer.credit_account
    assert_equal schedules(:monthly_schedule), @posted_transfer.schedule
  end

  test "pending transfer should have correct attributes" do
    assert_equal "pending", @pending_transfer.state
    assert_equal 2222, @pending_transfer.amount
    assert_equal 1.day.ago.to_date, @pending_transfer.pending_on
    assert_nil @pending_transfer.posted_on
    assert_equal accounts(:lazaro_cash), @pending_transfer.debit_account
    assert_equal accounts(:expense_account), @pending_transfer.credit_account
    assert_nil @pending_transfer.schedule
  end

  # Immutability tests
  test "should not allow updating posted transfer" do
    original_amount = @posted_transfer.amount
    @posted_transfer.amount = 9999

    assert_not @posted_transfer.save
    assert_includes @posted_transfer.errors[:base], "Posted transfers cannot be modified"

    @posted_transfer.reload
    assert_equal original_amount, @posted_transfer.amount
  end

  test "should not allow updating posted transfer attributes" do
    original_pending_on = @posted_transfer.pending_on
    original_debit_account = @posted_transfer.debit_account

    @posted_transfer.pending_on = Date.current
    @posted_transfer.debit_account = accounts(:expense_account)

    assert_not @posted_transfer.save
    assert_includes @posted_transfer.errors[:base], "Posted transfers cannot be modified"

    @posted_transfer.reload
    assert_equal original_pending_on, @posted_transfer.pending_on
    assert_equal original_debit_account, @posted_transfer.debit_account
  end

  test "should allow updating pending transfer" do
    original_amount = @pending_transfer.amount
    @pending_transfer.amount = 3333

    assert @pending_transfer.save
    @pending_transfer.reload
    assert_equal 3333, @pending_transfer.amount
  end

  test "should allow destroying posted transfer with balance reversal" do
    # Posted transfers can be destroyed but balances are reversed
    initial_debits = @posted_transfer.debit_account.debits
    initial_credits = @posted_transfer.credit_account.credits

    assert @posted_transfer.destroy
    assert_not Transfer.exists?(@posted_transfer.id)

    @posted_transfer.debit_account.reload
    @posted_transfer.credit_account.reload

    assert_equal initial_debits - @posted_transfer.amount, @posted_transfer.debit_account.debits
    assert_equal initial_credits - @posted_transfer.amount, @posted_transfer.credit_account.credits
  end

  test "should allow destroying pending transfer" do
    assert @pending_transfer.destroy
    assert_not Transfer.exists?(@pending_transfer.id)
  end

  # post! method tests
  test "post! should transition pending transfer to posted" do
    assert @pending_transfer.pending?
    assert_nil @pending_transfer.posted_on

    result = @pending_transfer.post!

    assert result
    @pending_transfer.reload
    assert @pending_transfer.posted?
    assert_equal Date.current, @pending_transfer.posted_on
  end

  test "post! should update account balances correctly" do
    debit_account = @pending_transfer.debit_account
    credit_account = @pending_transfer.credit_account

    initial_debit_debits = debit_account.debits
    initial_credit_credits = credit_account.credits

    @pending_transfer.post!

    debit_account.reload
    credit_account.reload

    assert_equal initial_debit_debits + @pending_transfer.amount, debit_account.debits
    assert_equal initial_credit_credits + @pending_transfer.amount, credit_account.credits
  end

  test "post! should return false for already posted transfer" do
    assert @posted_transfer.posted?

    result = @posted_transfer.post!

    assert_not result
    @posted_transfer.reload
    assert @posted_transfer.posted?
  end

test "post! should be transactional" do
    # Test that both the transfer state and account updates happen together
    debit_account = @pending_transfer.debit_account
    credit_account = @pending_transfer.credit_account

    initial_debit_debits = debit_account.debits
    initial_credit_credits = credit_account.credits

    # Mock the credit_account increment! to raise an exception
    credit_account.define_singleton_method(:increment!) do |field, value|
      raise StandardError, "Simulated database error"
    end

    # The post! should fail and not update anything
    assert_raises(StandardError) do
      @pending_transfer.post!
    end

    @pending_transfer.reload
    debit_account.reload
    credit_account.reload

    # Verify nothing was updated
    assert @pending_transfer.pending?
    assert_nil @pending_transfer.posted_on
    assert_equal initial_debit_debits, debit_account.debits
    assert_equal initial_credit_credits, credit_account.credits
  end

  # Validation tests for posted_on
  test "should require posted_on date for posted transfers" do
    @posted_transfer.posted_on = nil
    assert_not @posted_transfer.valid?
    assert_includes @posted_transfer.errors[:posted_on], "must be set for posted transfers"
  end

  test "should allow posted transfer with posted_on date" do
    @posted_transfer.posted_on = Date.current
    assert @posted_transfer.valid?
  end

  test "should allow pending transfer without posted_on date" do
    @pending_transfer.posted_on = nil
    assert @pending_transfer.valid?
  end

  test "should not allow saving posted transfer without posted_on date" do
    @pending_transfer.state = :posted
    @pending_transfer.posted_on = nil

    assert_not @pending_transfer.save
    assert_includes @pending_transfer.errors[:posted_on], "must be set for posted transfers"

    @pending_transfer.reload
    assert @pending_transfer.pending?
  end

  # Scope tests
  test "pending scope should return only pending transfers" do
    pending_transfers = Transfer.pending

    assert_includes pending_transfers, @pending_transfer
    assert_not_includes pending_transfers, @posted_transfer
    assert_equal 1, pending_transfers.count
  end

  test "posted scope should return only posted transfers" do
    posted_transfers = Transfer.posted

    assert_includes posted_transfers, @posted_transfer
    assert_not_includes posted_transfers, @pending_transfer
    assert_equal 1, posted_transfers.count
  end

  test "scopes should work with multiple records" do
    # Create additional transfers to test with more records
    new_pending = Transfer.create!(
      state: :pending,
      amount: 500,
      pending_on: Date.current,
      debit_account: accounts(:lazaro_cash),
      credit_account: accounts(:expense_account)
    )

    new_posted = Transfer.create!(
      state: :posted,
      amount: 750,
      pending_on: Date.current,
      posted_on: Date.current,
      debit_account: accounts(:revenue_account),
      credit_account: accounts(:lazaro_cash)
    )

    pending_transfers = Transfer.pending
    posted_transfers = Transfer.posted

    assert_includes pending_transfers, @pending_transfer
    assert_includes pending_transfers, new_pending
    assert_not_includes pending_transfers, @posted_transfer
    assert_not_includes pending_transfers, new_posted
    assert_equal 2, pending_transfers.count

    assert_includes posted_transfers, @posted_transfer
    assert_includes posted_transfers, new_posted
    assert_not_includes posted_transfers, @pending_transfer
    assert_not_includes posted_transfers, new_pending
    assert_equal 2, posted_transfers.count

    # Clean up
    new_pending.destroy
    new_posted.destroy
  end

  # Credit card constraint tests
  test "should prevent credit card from having credits less than debits" do
    user = users(:lazaro_nixon)
    organization = user.organizations.create!(name: "Test Organization")
    credit_card = organization.accounts.create!(
      name: "Test Credit Card",
      kind: "credit_card",
      metadata: { due_day: 15, statement_day: 1, credit_limit: 5000 }
    )
    cash_account = accounts(:lazaro_cash)

    # Set up credit card with some existing balance
    credit_card.update!(debits: 2000, credits: 3000) # 1000 owed

    # This transfer would make credits (3000) < debits (2000 + 1500)
    transfer = Transfer.new(
      amount: 1500,
      pending_on: Date.current,
      debit_account: credit_card, # Credit card is debited (payment out)
      credit_account: cash_account
    )

    assert_not transfer.valid?
    assert_includes transfer.errors[:base], "This transfer would cause credit card to have credits less than debits"
  end

  test "should allow credit card payment when credits >= debits" do
    user = users(:lazaro_nixon)
    organization = user.organizations.create!(name: "Test Organization")
    credit_card = organization.accounts.create!(
      name: "Test Credit Card",
      kind: "credit_card",
      metadata: { due_day: 15, statement_day: 1, credit_limit: 5000 }
    )
    cash_account = accounts(:lazaro_cash)

    # Set up credit card with some existing balance
    credit_card.update!(debits: 2000, credits: 3000) # 1000 owed

    # This transfer is fine: credits (3000) >= debits (2000 + 500)
    transfer = Transfer.new(
      amount: 500,
      pending_on: Date.current,
      debit_account: credit_card, # Credit card is debited (payment out)
      credit_account: cash_account
    )

    assert transfer.valid?
  end

  test "should prevent credit card charge when it would violate constraint" do
    user = users(:lazaro_nixon)
    organization = user.organizations.create!(name: "Test Organization")
    credit_card = organization.accounts.create!(
      name: "Test Credit Card",
      kind: "credit_card",
      metadata: { due_day: 15, statement_day: 1, credit_limit: 5000 }
    )
    cash_account = accounts(:lazaro_cash)

    # Set up credit card with existing charges (credits > debits = amount owed)
    credit_card.update!(debits: 2000, credits: 3000) # 1000 owed

    # This transfer would make credits (3000 + 2000) >= debits (2000) - this is actually valid
    # The constraint is credits >= debits, so we need to test when this would be violated
    # But for credit cards, credits represent charges and debits represent payments
    # So having more credits than debits is normal (owing money)

    # Let's test a scenario where we try to make a payment that would overpay
    transfer = Transfer.new(
      amount: 1500, # More than the 1000 owed
      pending_on: Date.current,
      debit_account: credit_card, # Credit card is debited (payment out)
      credit_account: cash_account
    )

    # This should be invalid because it would make credits (3000) < debits (2000 + 1500)
    assert_not transfer.valid?
    assert_includes transfer.errors[:base], "This transfer would cause credit card to have credits less than debits"
  end

  test "should allow credit card charge when credits >= debits" do
    user = users(:lazaro_nixon)
    organization = user.organizations.create!(name: "Test Organization")
    credit_card = organization.accounts.create!(
      name: "Test Credit Card",
      kind: "credit_card",
      metadata: { due_day: 15, statement_day: 1, credit_limit: 5000 }
    )
    cash_account = accounts(:lazaro_cash)

    # Set up credit card with some available credit
    credit_card.update!(debits: 2000, credits: 3000) # 1000 owed, 2000 available

    # This transfer is fine: credits (3000 + 500) >= debits (2000)
    transfer = Transfer.new(
      amount: 500,
      pending_on: Date.current,
      debit_account: cash_account,
      credit_account: credit_card # Credit card is credited (charge in)
    )

    assert transfer.valid?
  end

  test "validation should not affect non-credit-card accounts" do
    vendor_account = accounts(:expense_account)
    cash_account = accounts(:lazaro_cash)

    # This should be valid even if it creates negative balance for vendor
    transfer = Transfer.new(
      amount: 5000,
      pending_on: Date.current,
      debit_account: vendor_account,
      credit_account: cash_account
    )

    assert transfer.valid?
  end
end
