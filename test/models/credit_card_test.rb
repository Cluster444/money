require "test_helper"

class CreditCardTest < ActiveSupport::TestCase
  def setup
    @user = users(:lazaro_nixon)
    @credit_card = @user.accounts.create!(
      name: "Test Credit Card",
      kind: "credit_card",
      metadata: { due_day: 15, statement_day: 1 }
    )
  end

  test "credit card account should be valid" do
    assert @credit_card.valid?
  end

  test "posted_balance should be credits minus debits for credit cards" do
    @credit_card.update!(debits: 1000, credits: 2500)
    assert_equal 1500, @credit_card.posted_balance
  end

  test "credit card with zero balance should have zero posted_balance" do
    @credit_card.update!(debits: 1000, credits: 1000)
    assert_equal 0, @credit_card.posted_balance
  end

  test "credit card should validate due_day in metadata" do
    @credit_card.metadata = { due_day: 0 }
    assert_not @credit_card.valid?
    assert_includes @credit_card.errors[:metadata], "due_day must be between 1 and 31"

    @credit_card.metadata = { due_day: 32 }
    assert_not @credit_card.valid?
    assert_includes @credit_card.errors[:metadata], "due_day must be between 1 and 31"

    @credit_card.metadata = { due_day: 15 }
    assert @credit_card.valid?
  end

  test "credit card should validate statement_day in metadata" do
    @credit_card.metadata = { statement_day: 0 }
    assert_not @credit_card.valid?
    assert_includes @credit_card.errors[:metadata], "statement_day must be between 1 and 31"

    @credit_card.metadata = { statement_day: 32 }
    assert_not @credit_card.valid?
    assert_includes @credit_card.errors[:metadata], "statement_day must be between 1 and 31"

    @credit_card.metadata = { statement_day: 1 }
    assert @credit_card.valid?
  end

  test "due_day should return integer from metadata" do
    @credit_card.metadata = { due_day: "15" }
    assert_equal 15, @credit_card.due_day
  end

  test "statement_day should return integer from metadata" do
    @credit_card.metadata = { statement_day: "1" }
    assert_equal 1, @credit_card.statement_day
  end

  test "next_statement_date should calculate correctly" do
    # Test with statement day of 1st
    @credit_card.metadata = { statement_day: 1 }

    # If today is after the 1st, next statement should be next month
    travel_to Date.new(2024, 1, 15) do
      assert_equal Date.new(2024, 2, 1), @credit_card.next_statement_date
    end

    # If today is before the 1st, next statement should be this month
    travel_to Date.new(2024, 1, 1) do
      assert_equal Date.new(2024, 1, 1), @credit_card.next_statement_date
    end
  end

  test "next_due_date should calculate correctly" do
    # Test with due day of 15th
    @credit_card.metadata = { due_day: 15 }

    # If today is after the 15th, next due date should be next month
    travel_to Date.new(2024, 1, 20) do
      assert_equal Date.new(2024, 2, 15), @credit_card.next_due_date
    end

    # If today is before the 15th, next due date should be this month
    travel_to Date.new(2024, 1, 10) do
      assert_equal Date.new(2024, 1, 15), @credit_card.next_due_date
    end
  end

  test "days_until_statement should calculate correctly" do
    @credit_card.metadata = { statement_day: 1 }

    travel_to Date.new(2024, 1, 15) do
      # 17 days until February 1st (31 - 15 + 1)
      assert_equal 17, @credit_card.days_until_statement
    end
  end

  test "days_until_due should calculate correctly" do
    @credit_card.metadata = { due_day: 15 }

    travel_to Date.new(2024, 1, 10) do
      assert_equal 5, @credit_card.days_until_due
    end
  end

  test "next_payment_date should calculate correctly" do
    @credit_card.metadata = { statement_day: 1 }

    # Payment date is day before statement date
    travel_to Date.new(2024, 1, 15) do
      # Next statement is Feb 1, so payment is Jan 31
      assert_equal Date.new(2024, 1, 31), @credit_card.next_payment_date
    end

    travel_to Date.new(2024, 1, 1) do
      # Next statement is Feb 1 (since Jan 1 is today), so payment is Jan 31
      assert_equal Date.new(2024, 1, 31), @credit_card.next_payment_date
    end
  end

  test "should create payment schedule automatically for credit card" do
    # Ensure there's a cash account first
    cash_account = @user.accounts.cash.first || @user.accounts.create!(name: "Cash", kind: "cash")

    credit_card = @user.accounts.create!(
      name: "Auto Credit Card",
      kind: "credit_card",
      metadata: { due_day: 15, statement_day: 1 }
    )

    # Schedule is created in after_create callback, so we check after creation
    schedule = Schedule.where(name: "Payment for Auto Credit Card").first
    assert_not_nil schedule
    assert_equal credit_card, schedule.debit_account
    assert_equal cash_account, schedule.credit_account
    assert_equal credit_card, schedule.relative_account
  end

  test "should not create payment schedule if missing due_day or statement_day" do
    credit_card = @user.accounts.create!(
      name: "Incomplete Credit Card",
      kind: "credit_card",
      metadata: { due_day: 15 } # Missing statement_day
    )

    assert_no_difference "Schedule.count" do
      credit_card
    end
  end

  test "should not create payment schedule if no cash account exists" do
    # Delete existing cash accounts
    @user.accounts.cash.destroy_all

    credit_card = @user.accounts.create!(
      name: "No Cash Credit Card",
      kind: "credit_card",
      metadata: { due_day: 15, statement_day: 1 }
    )

    assert_no_difference "Schedule.count" do
      credit_card
    end
  end
end
