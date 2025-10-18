require "test_helper"

class CreditCardAutoScheduleTest < ActiveSupport::TestCase
  def setup
    @user = users(:lazaro_nixon)
    @organization = @user.organizations.first
    @cash_account = Account.create!(
      user: @user,
      organization: @organization,
      name: "Checking",
      kind: "cash",
      debits: 1000,
      credits: 0
    )
  end

  test "credit card account automatically creates payment schedule" do
    credit_card = Account.create!(
      user: @user,
      organization: @organization,
      name: "Visa",
      kind: "credit_card",
      debits: 0,
      credits: 500,
      metadata: { due_day: 15, statement_day: 1, credit_limit: 4000 }
    )

    assert_equal 1, credit_card.debit_schedules.count
    schedule = credit_card.debit_schedules.first

    assert_equal "Payment for Visa", schedule.name
    assert_equal credit_card, schedule.debit_account
    assert_equal @organization.accounts.cash.first, schedule.credit_account
    assert_equal credit_card, schedule.relative_account
    assert_equal "month", schedule.period
    assert_equal credit_card.next_payment_date, schedule.starts_on
  end

  test "non-credit card accounts do not create schedules" do
    vendor_account = Account.create!(
      user: @user,
      organization: @organization,
      name: "Vendor",
      kind: "vendor",
      debits: 0,
      credits: 100
    )

    assert_equal 0, vendor_account.debit_schedules.count
  end

  test "credit card without due_day cannot be created" do
    assert_raises(ActiveRecord::RecordInvalid) do
      Account.create!(
        user: @user,
        organization: @organization,
        name: "Visa",
        kind: "credit_card",
        debits: 0,
        credits: 500,
        statement_day: 1
      )
    end
  end

  test "credit card without statement_day cannot be created" do
    assert_raises(ActiveRecord::RecordInvalid) do
      Account.create!(
        user: @user,
        organization: @organization,
        name: "Visa",
        kind: "credit_card",
        debits: 0,
        credits: 500,
        due_day: 15
      )
    end
  end

  test "credit card without cash account does not create schedule" do
    # Delete all cash accounts first
    @organization.accounts.cash.destroy_all

    credit_card = Account.create!(
      user: @user,
      organization: @organization,
      name: "Mastercard",
      kind: "credit_card",
      debits: 0,
      credits: 500,
      metadata: { due_day: 15, statement_day: 1, credit_limit: 3500 }
    )

    assert_equal 0, credit_card.debit_schedules.count
  end
end
