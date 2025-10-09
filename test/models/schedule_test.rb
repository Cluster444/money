require "test_helper"

class ScheduleTest < ActiveSupport::TestCase
  setup do
    @schedule = schedules(:monthly_schedule)
  end

  # Validations tests
  test "should be valid with required attributes" do
    assert @schedule.valid?
  end

  test "should require name" do
    @schedule.name = nil
    assert_not @schedule.valid?
    assert_includes @schedule.errors[:name], "can't be blank"
  end

  test "should require amount" do
    @schedule.amount = nil
    assert_not @schedule.valid?
    assert_includes @schedule.errors[:amount], "can't be blank"
  end

  test "should require amount greater than 0" do
    @schedule.amount = 0
    assert_not @schedule.valid?
    assert_includes @schedule.errors[:amount], "must be greater than 0"

    @schedule.amount = -100
    assert_not @schedule.valid?
    assert_includes @schedule.errors[:amount], "must be greater than 0"
  end

  test "should require starts_on" do
    @schedule.starts_on = nil
    assert_not @schedule.valid?
    assert_includes @schedule.errors[:starts_on], "can't be blank"
  end

  test "should require debit_account" do
    @schedule.debit_account = nil
    assert_not @schedule.valid?
    assert_includes @schedule.errors[:debit_account], "must exist"
  end

  test "should require credit_account" do
    @schedule.credit_account = nil
    assert_not @schedule.valid?
    assert_includes @schedule.errors[:credit_account], "must exist"
  end

  test "should require different debit and credit accounts" do
    @schedule.credit_account = @schedule.debit_account
    assert_not @schedule.valid?
    assert_includes @schedule.errors[:credit_account], "must be different from debit account"
  end

  # Association tests
  test "should belong to debit_account" do
    assert_respond_to @schedule, :debit_account
    assert_equal accounts(:revenue_account), @schedule.debit_account
  end

  test "should belong to credit_account" do
    assert_respond_to @schedule, :credit_account
    assert_equal accounts(:lazaro_cash), @schedule.credit_account
  end

  test "should have many transfers" do
    assert_respond_to @schedule, :transfers
    assert @schedule.transfers.include?(transfers(:posted_transfer))
  end

  # Deletion tests
  test "should nullify schedule_id on related transfers when schedule destroyed" do
    transfer = transfers(:posted_transfer)
    assert_equal @schedule.id, transfer.schedule_id

    @schedule.destroy

    transfer.reload
    assert_nil transfer.schedule_id
    assert_nothing_raised { transfer.reload }  # Transfer should still exist
  end

  test "should not destroy transfers when schedule destroyed" do
    initial_transfer_count = Transfer.count

    @schedule.destroy

    assert_equal initial_transfer_count, Transfer.count
  end

  # Fixture tests
  test "monthly schedule should have correct attributes" do
    assert_equal "Monthly Revenue Transfer", @schedule.name
    assert_equal 1234, @schedule.amount
    assert_equal "month", @schedule.period
    assert_equal 1, @schedule.frequency
    assert_equal 2.weeks.ago.to_date, @schedule.starts_on
    assert_equal 6.months.from_now.to_date, @schedule.ends_on
    assert_nil @schedule.last_materialized_on
    assert_equal accounts(:revenue_account), @schedule.debit_account
    assert_equal accounts(:lazaro_cash), @schedule.credit_account
  end

  # Additional tests
  test "should allow optional ends_on when frequency is not set" do
    @schedule.frequency = nil
    @schedule.period = nil
    @schedule.ends_on = Date.today + 1.month
    assert @schedule.valid?

    @schedule.ends_on = nil
    assert @schedule.valid?
  end

  test "should allow optional last_materialized_on" do
    @schedule.last_materialized_on = Date.yesterday
    assert @schedule.valid?

    @schedule.last_materialized_on = nil
    assert @schedule.valid?
  end

  test "should allow optional period when frequency is not set" do
    @schedule.frequency = nil
    @schedule.period = "week"
    assert @schedule.valid?

    @schedule.period = nil
    assert @schedule.valid?
  end

  test "should allow optional frequency" do
    @schedule.frequency = 2
    assert @schedule.valid?

    @schedule.frequency = nil
    assert @schedule.valid?
  end

  test "should require ends_on when frequency is set" do
    @schedule.frequency = 1
    @schedule.ends_on = nil
    assert_not @schedule.valid?
    assert_includes @schedule.errors[:ends_on], "must be present when frequency is set"
  end

  test "should require period when frequency is set" do
    @schedule.frequency = 1
    @schedule.period = nil
    assert_not @schedule.valid?
    assert_includes @schedule.errors[:period], "must be present when frequency is set"
  end

  test "should validate period inclusion" do
    @schedule.period = "invalid"
    assert_not @schedule.valid?
    assert_includes @schedule.errors[:period], "is not included in the list"
  end

  # transfer_dates method tests
  test "future single date schedule should return single date when up_to_date includes start date" do
    schedule = schedules(:future_single_date)
    up_to_date = 3.weeks.from_now.to_date

    dates = schedule.transfer_dates(up_to_date)

    assert_equal 1, dates.length
    assert_equal schedule.starts_on, dates.first
  end

  test "future single date schedule should return empty when up_to_date before start date" do
    schedule = schedules(:future_single_date)
    up_to_date = 1.week.from_now.to_date

    dates = schedule.transfer_dates(up_to_date)

    assert_empty dates
  end

test "past single date schedule should return single date when up_to_date after start date" do
    schedule = schedules(:past_no_dates)
    up_to_date = Date.today

    dates = schedule.transfer_dates(up_to_date)

    assert_equal 1, dates.length
    assert_equal schedule.starts_on, dates.first
  end

  test "past single date schedule should return single date when up_to_date includes start date" do
    schedule = schedules(:past_no_dates)
    up_to_date = 1.week.ago.to_date

    dates = schedule.transfer_dates(up_to_date)

    assert_equal 1, dates.length
    assert_equal schedule.starts_on, dates.first
  end

test "weekly schedule should produce dates up to specified date" do
    schedule = schedules(:weekly_schedule)
    up_to_date = 1.week.from_now.to_date

    dates = schedule.transfer_dates(up_to_date)

    # Should include dates from 3 weeks ago up to 1 week from now
    assert dates.length >= 4
    assert dates.include?(schedule.starts_on)
    assert dates.all? { |date| date <= up_to_date }

    # Check that dates are weekly
    dates.each_cons(2) do |date1, date2|
      assert_equal 7, (date2 - date1).to_i
    end
  end

test "monthly schedule with end date should return dates when up_to_date before ends_on" do
    schedule = schedules(:monthly_with_end_before)
    up_to_date = 1.month.from_now.to_date

    dates = schedule.transfer_dates(up_to_date)

    # Should include dates from 2 months ago up to 1 month from now
    assert dates.length >= 3
    assert dates.include?(schedule.starts_on)
    assert dates.all? { |date| date <= up_to_date }
    assert dates.all? { |date| date <= schedule.ends_on }

    # Check that dates are approximately monthly (within a reasonable range)
    dates.each_cons(2) do |date1, date2|
      days_diff = (date2 - date1).to_i
      assert days_diff >= 28 && days_diff <= 31, "Expected approximately 1 month, got #{days_diff} days"
    end
  end

test "monthly schedule with end date should return dates when up_to_date after ends_on" do
    schedule = schedules(:monthly_with_end_after)
    up_to_date = Date.today

    dates = schedule.transfer_dates(up_to_date)

    # Should include dates from 3 months ago up to 1 week ago (ends_on)
    assert dates.length >= 3
    assert dates.include?(schedule.starts_on)
    assert dates.all? { |date| date <= schedule.ends_on }
    assert dates.all? { |date| date <= up_to_date }

    # Check that dates are approximately monthly (within a reasonable range)
    dates.each_cons(2) do |date1, date2|
      days_diff = (date2 - date1).to_i
      assert days_diff >= 28 && days_diff <= 31, "Expected approximately 1 month, got #{days_diff} days"
    end
  end

test "monthly schedule should handle frequency correctly" do
    schedule = schedules(:monthly_schedule)
    schedule.frequency = 2  # Every 2 months
    up_to_date = 6.months.from_now.to_date

    dates = schedule.transfer_dates(up_to_date)

    # Check that dates are approximately every 2 months (within a reasonable range)
    dates.each_cons(2) do |date1, date2|
      days_diff = (date2 - date1).to_i
      assert days_diff >= 59 && days_diff <= 62, "Expected approximately 2 months, got #{days_diff} days"
    end
  end

  test "transfer_dates should be inclusive of up_to_date" do
    schedule = schedules(:weekly_schedule)
    up_to_date = schedule.starts_on + 2.weeks  # Exactly 2 weeks after start

    dates = schedule.transfer_dates(up_to_date)

    assert dates.include?(up_to_date), "Should include the up_to_date when it falls on a scheduled date"
  end

  test "transfer_dates should handle different periods" do
    # Test daily period
    daily_schedule = schedules(:weekly_schedule).dup
    daily_schedule.period = "day"
    daily_schedule.frequency = 1
    daily_schedule.ends_on = daily_schedule.starts_on + 1.month
    up_to_date = daily_schedule.starts_on + 3.days

    dates = daily_schedule.transfer_dates(up_to_date)
    assert_equal 4, dates.length  # start + 3 days

    # Test yearly period
    yearly_schedule = schedules(:monthly_schedule).dup
    yearly_schedule.period = "year"
    yearly_schedule.frequency = 1
    yearly_schedule.ends_on = yearly_schedule.starts_on + 3.years
    up_to_date = yearly_schedule.starts_on + 2.years

    dates = yearly_schedule.transfer_dates(up_to_date)
    assert_equal 3, dates.length  # start + 2 years
  end

  test "planned_transfers should create transfers with correct attributes" do
    dates = [ Date.today, Date.today + 1.week, Date.today + 2.weeks ]

    transfers = @schedule.planned_transfers(dates)

    assert_equal 3, transfers.length

    transfers.each_with_index do |transfer, index|
      assert_equal @schedule.amount, transfer.amount
      assert_equal dates[index], transfer.pending_on
      assert_equal @schedule.debit_account, transfer.debit_account
      assert_equal @schedule.credit_account, transfer.credit_account
      assert_equal @schedule, transfer.schedule
      assert_equal "pending", transfer.state
      assert transfer.new_record?
    end
  end

  test "planned_transfers should handle empty dates array" do
    transfers = @schedule.planned_transfers([])

    assert_empty transfers
  end

  # create_pending_transfers method tests
  test "create_pending_transfers generates transfers for today" do
    schedule = schedules(:daily_schedule_for_today)

    # Verify initial state
    assert_equal 1.day.ago.to_date, schedule.last_materialized_on
    assert_equal 0, schedule.transfers.where(pending_on: Date.current).count

    # Create pending transfers
    schedule.create_pending_transfers

    # Verify transfer was created for today
    assert_equal 1, schedule.transfers.where(pending_on: Date.current).count

    # Verify transfer attributes
    transfer = schedule.transfers.find_by(pending_on: Date.current)
    assert_equal 250, transfer.amount
    assert_equal "pending", transfer.state
    assert_equal schedule.debit_account, transfer.debit_account
    assert_equal schedule.credit_account, transfer.credit_account

    # Verify last_materialized_on was updated
    schedule.reload
    assert_equal Date.current, schedule.last_materialized_on
  end

  test "create_pending_transfers is idempotent" do
    schedule = schedules(:daily_schedule_for_today)

    # Run twice
    schedule.create_pending_transfers
    schedule.create_pending_transfers

    # Should still only have one transfer for today
    assert_equal 1, schedule.transfers.where(pending_on: Date.current).count
  end

  test "create_pending_transfers handles schedules with no previous materialization" do
    schedule = schedules(:future_single_date)
    schedule.update!(starts_on: Date.current, last_materialized_on: nil)

    # Should create transfer for today
    schedule.create_pending_transfers

    assert_equal 1, schedule.transfers.where(pending_on: Date.current).count
    assert_equal Date.current, schedule.reload.last_materialized_on
  end

test "create_pending_transfers handles edge cases gracefully" do
    schedule = schedules(:daily_schedule_for_today)

    # Test with no dates to materialize (already up to date)
    schedule.update!(last_materialized_on: Date.current)

    # Should not create any new transfers
    schedule.create_pending_transfers

    assert_equal 0, schedule.transfers.where(pending_on: Date.current).count
  end

  test "create_pending_transfers only creates transfers for dates in range" do
    schedule = schedules(:daily_schedule_for_today)

    # Should not create transfers for future dates
    schedule.create_pending_transfers

    assert_equal 0, schedule.transfers.where("pending_on > ?", Date.current).count
  end
end
