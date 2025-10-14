require "test_helper"

class AdjustmentMoneyConversionTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:lazaro_nixon)
    @account = @user.accounts.cash.first
    login_as @user
  end

  test "full adjustment flow with target balance inputs" do
    # Start with initial balance
    @account.update!(debits: 10000, credits: 5000)  # Set initial balance to $50
    initial_balance = @account.posted_balance

    # Create adjustment with target balance
    get new_account_adjustment_path(@account)
    assert_response :success

    post account_adjustments_path(@account), params: {
      adjustment: {
        target_balance: "222.00",  # User wants balance to be $222.00
        note: "Test adjustment with target balance"
      }
    }

    assert_redirected_to account_adjustments_path(@account)

    # Verify balance was updated correctly to target
    @account.reload
    assert_equal 22200, @account.posted_balance

    # Verify adjustment was stored with correct amount
    adjustment = Adjustment.last
    assert_equal 17200, adjustment.debit_amount  # 22200 - 5000 = 17200
    assert_equal "Test adjustment with target balance", adjustment.note

    # Edit the adjustment
    get edit_account_adjustment_path(@account, adjustment)
    assert_response :success
    assert_select "input[name='adjustment[target_balance]']"

    # Update with new target balance
    patch account_adjustment_path(@account, adjustment), params: {
      adjustment: {
        target_balance: "333.33",  # Update to $333.33
        note: "Updated adjustment"
      }
    }

    assert_redirected_to account_adjustments_path(@account)

    # Verify balance was updated correctly
    @account.reload
    assert_equal 33333, @account.posted_balance  # Should be exactly $333.33

    # Verify adjustment was updated
    adjustment.reload
    assert_equal 28333, adjustment.debit_amount  # 33333 - 5000 = 28333
    assert_equal "Updated adjustment", adjustment.note

    # Delete the adjustment
    delete account_adjustment_path(@account, adjustment)
    assert_redirected_to account_adjustments_path(@account)

    # Verify balance was restored to initial
    @account.reload
    assert_equal initial_balance, @account.posted_balance
  end

  private

  def login_as(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end
end
