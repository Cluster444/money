require "test_helper"

class AdjustmentTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      first_name: "Test",
      last_name: "User",
      email_address: "test@example.com",
      password: "password123"
    )
    @account = Account::Cash.create!(
      user: @user,
      name: "Test Account",
      debits: 1000,
      credits: 500
    )
  end

  test "should be valid with credit amount and note" do
    adjustment = Adjustment.new(
      account: @account,
      credit_amount: 100,
      note: "Test credit adjustment"
    )
    assert adjustment.valid?
  end

  test "should be valid with debit amount and note" do
    adjustment = Adjustment.new(
      account: @account,
      debit_amount: 50,
      note: "Test debit adjustment"
    )
    assert adjustment.valid?
  end

  test "should be invalid without account" do
    adjustment = Adjustment.new(
      credit_amount: 100,
      note: "Test adjustment"
    )
    assert_not adjustment.valid?
    assert_includes adjustment.errors[:account], "must exist"
  end

  test "should be invalid without note" do
    adjustment = Adjustment.new(
      account: @account,
      credit_amount: 100
    )
    assert_not adjustment.valid?
    assert_includes adjustment.errors[:note], "can't be blank"
  end

  test "should be invalid without either credit or debit amount" do
    adjustment = Adjustment.new(
      account: @account,
      note: "Test adjustment"
    )
    assert_not adjustment.valid?
    assert_includes adjustment.errors[:base], "Adjustment must change the account balance"
  end

  test "should be invalid with both credit and debit amount" do
    adjustment = Adjustment.new(
      account: @account,
      credit_amount: 100,
      debit_amount: 50,
      note: "Test adjustment"
    )
    assert_not adjustment.valid?
    assert_includes adjustment.errors[:base], "Cannot have both credit amount and debit amount"
  end

test "should increment account credits when credit adjustment is created" do
    initial_credits = @account.credits
    adjustment = Adjustment.create!(
      account: @account,
      credit_amount: 1.00,
      note: "Test credit adjustment"
    )

    @account.reload
    assert_equal initial_credits + 1.00, @account.credits
  end

  test "should increment account debits when debit adjustment is created" do
    initial_debits = @account.debits
    adjustment = Adjustment.create!(
      account: @account,
      debit_amount: 0.50,
      note: "Test debit adjustment"
    )

    @account.reload
    assert_equal initial_debits + 0.50, @account.debits
  end

  test "should belong to account" do
    adjustment = Adjustment.new(
      account: @account,
      credit_amount: 100,
      note: "Test adjustment"
    )
    assert_respond_to adjustment, :account
    assert_equal @account, adjustment.account
  end

  test "should update account balance when credit amount changes" do
    adjustment = Adjustment.create!(
      account: @account,
      credit_amount: 100,
      note: "Test adjustment"
    )
    initial_credits = @account.credits

    # Update credit amount
    adjustment.update!(credit_amount: 200)

    @account.reload
    assert_equal initial_credits + 100, @account.credits  # 200 - 100 = 100 increase
  end

  test "should update account balance when debit amount changes" do
    adjustment = Adjustment.create!(
      account: @account,
      debit_amount: 50,
      note: "Test adjustment"
    )
    initial_debits = @account.debits

    # Update debit amount
    adjustment.update!(debit_amount: 75)

    @account.reload
    assert_equal initial_debits + 25, @account.debits  # 75 - 50 = 25 increase
  end

  test "should handle credit to debit conversion" do
    adjustment = Adjustment.create!(
      account: @account,
      credit_amount: 100,
      note: "Test adjustment"
    )
    initial_credits = @account.credits
    initial_debits = @account.debits

    # Convert to debit adjustment
    adjustment.update!(credit_amount: nil, debit_amount: 75)

    @account.reload
    assert_equal initial_credits - 100, @account.credits  # Remove original credit
    assert_equal initial_debits + 75, @account.debits     # Add new debit
  end

  test "should handle debit to credit conversion" do
    adjustment = Adjustment.create!(
      account: @account,
      debit_amount: 50,
      note: "Test adjustment"
    )
    initial_credits = @account.credits
    initial_debits = @account.debits

    # Convert to credit adjustment
    adjustment.update!(debit_amount: nil, credit_amount: 125)

    @account.reload
    assert_equal initial_debits - 50, @account.debits      # Remove original debit
    assert_equal initial_credits + 125, @account.credits   # Add new credit
  end

  test "should reverse account balance when destroyed" do
    adjustment = Adjustment.create!(
      account: @account,
      credit_amount: 100,
      note: "Test adjustment"
    )
    initial_credits = @account.credits

    adjustment.destroy

    @account.reload
    assert_equal initial_credits - 100, @account.credits
  end

  test "should reverse debit balance when destroyed" do
    adjustment = Adjustment.create!(
      account: @account,
      debit_amount: 50,
      note: "Test adjustment"
    )
    initial_debits = @account.debits

    adjustment.destroy

    @account.reload
    assert_equal initial_debits - 50, @account.debits
  end

  test "should handle multiple balance updates correctly" do
    initial_credits = @account.credits
    initial_debits = @account.debits

    # Create credit adjustment
    adjustment = Adjustment.create!(
      account: @account,
      credit_amount: 100,
      note: "Initial adjustment"
    )

    @account.reload
    assert_equal initial_credits + 100, @account.credits

    # Update to larger credit amount
    adjustment.update!(credit_amount: 150)

    @account.reload
    assert_equal initial_credits + 150, @account.credits

    # Convert to debit
    adjustment.update!(credit_amount: nil, debit_amount: 75)

    @account.reload
    assert_equal initial_credits, @account.credits      # Back to original
    assert_equal initial_debits + 75, @account.debits   # Plus new debit

    # Destroy adjustment
    adjustment.destroy

    @account.reload
    assert_equal initial_credits, @account.credits      # Back to original
    assert_equal initial_debits, @account.debits        # Back to original
  end

  test "should not update balance when note changes" do
    adjustment = Adjustment.create!(
      account: @account,
      credit_amount: 100,
      note: "Original note"
    )
    initial_credits = @account.credits

    # Update only the note
    adjustment.update!(note: "Updated note")

    @account.reload
    assert_equal initial_credits, @account.credits  # No change
    assert_equal "Updated note", adjustment.note
  end

  test "should handle zero amount updates" do
    adjustment = Adjustment.create!(
      account: @account,
      credit_amount: 100,
      note: "Test adjustment"
    )
    initial_credits = @account.credits

    # Set amount to zero (should be treated as nil)
    adjustment.update!(credit_amount: 0)

    @account.reload
    assert_equal initial_credits - 100, @account.credits  # Remove original credit
  end
end
