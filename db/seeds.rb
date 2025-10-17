return unless Rails.env.development?

# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Clear existing data in the correct order to avoid foreign key constraints
Account.destroy_all
User.destroy_all if ENV["DESTROY_ALL"].present?

ApplicationRecord.transaction do
  # Create test user
  user = User.find_or_create_by!(email_address: "user@test.dev") do |u|
    u.password = "password"
    u.password_confirmation = "password"
    u.first_name = "John"
    u.last_name = "Doe"
  end
  personal = user.organizations.first

  %w[Checking Savings].each do |cash_acct|
    personal.accounts.create!(
      kind: "cash",
      name: "Checking",
      metadata: {}
    )
  end
  checking = Account.first

  visa_cc = personal.accounts.create!(
    kind: "credit_card",
    name: "Visa Card",
    metadata: {
      due_day: 10,
      statement_day: 15
    }
  )

  [ "Rent", "Car", "Car Insurance", "Gas", "Electricity",
    "Phone", "Internet", "Job" ].each do |vendor_acct|
    personal.accounts.create!(
      kind: "vendor",
      name: vendor_acct,
      metadata: {}
    )
  end

  Schedule.create!(
    name: "Pay Check",
    debit_account: checking,
    credit_account: Account.find_by(name: "Job"),
    starts_on: Date.current.beginning_of_month - 5.months,
    frequency: 1, period: "week",
    amount: 100000,
  )

  Schedule.create!(
    name: "Rent",
    debit_account: Account.find_by(name: "Rent"),
    credit_account: checking,
    starts_on: Date.current.beginning_of_month - 5.months,
    frequency: 1, period: "month",
    amount: 240000,
  )

  Schedule.create!(
    name: "Car",
    debit_account: Account.find_by(name: "Car"),
    credit_account: checking,
    starts_on: Date.current.beginning_of_month + 3.days - 5.months,
    frequency: 1, period: "month",
    amount: 66500,
  )

  Schedule.create!(
    name: "Car Insurance",
    debit_account: Account.find_by(name: "Car Insurance"),
    credit_account: checking,
    starts_on: Date.current.beginning_of_month + 6.days - 5.months,
    frequency: 1, period: "month",
    amount: 14500,
  )

  Schedule.create!(
    name: "Gas",
    debit_account: Account.find_by(name: "Gas"),
    credit_account: checking,
    starts_on: Date.current.beginning_of_month + 9.days - 5.months,
    frequency: 1, period: "month",
    amount: 4500,
  )

  Schedule.create!(
    name: "Electricity",
    debit_account: Account.find_by(name: "Electricity"),
    credit_account: checking,
    starts_on: Date.current.beginning_of_month + 12.days - 5.months,
    frequency: 1, period: "month",
    amount: 15000,
  )

  Schedule.create!(
    name: "Phone",
    debit_account: Account.find_by(name: "Phone"),
    credit_account: checking,
    starts_on: Date.current.beginning_of_month + 15.days - 5.months,
    frequency: 1, period: "month",
    amount: 8000,
  )

  Schedule.create!(
    name: "Internet",
    debit_account: Account.find_by(name: "Internet"),
    credit_account: checking,
    starts_on: Date.current.beginning_of_month + 18.days - 5.months,
    frequency: 1, period: "month",
    amount: 12000,
  )

  # Backfill transfers for all schedules
  Schedule.all.each do |schedule|
    transfer_dates = schedule.transfer_dates(Date.current)
    transfer_dates.each do |date|
      schedule.debit_account.increment!(:debits, schedule.amount)
      schedule.credit_account.increment!(:credits, schedule.amount)
      Transfer.find_or_create_by!(
        schedule: schedule,
        pending_on: date,
        posted_on: date,
        amount: schedule.amount,
        debit_account: schedule.debit_account,
        credit_account: schedule.credit_account,
        state: "posted"
      )
    end
    # Set last_materialized_on to the date of the last transfer created
    schedule.update!(last_materialized_on: transfer_dates.last) if transfer_dates.any?
  end
end
