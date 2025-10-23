require "test_helper"

class AdjustmentMoneyConversionTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:lazaro_nixon)
    @account = @user.accounts.cash.first
    login_as @user
  end

  test "full adjustment flow with target balance inputs" do
    # Start with initial balance
    @account.update!(debits: 100.00, credits: 50.00)  # Set initial balance to $50
    initial_balance = @account.posted_balance

    # Create adjustment with target balance
    get new_organization_account_adjustment_path(@account.organization, @account)
    assert_response :success

    post organization_account_adjustments_path(@account.organization, @account), params: {
      adjustment: {
        target_balance: "222.00",  # User wants balance to be $222.00
        note: "Test adjustment with target balance"
      }
    }

    assert_redirected_to organization_account_adjustments_path(@account.organization, @account)

    # Verify balance was updated correctly to target
    @account.reload
    assert_equal 222.00, @account.posted_balance

    # Verify adjustment was stored with correct amount
    adjustment = Adjustment.last
    assert_equal 172.00, adjustment.debit_amount  # 222.00 - 50.00 = 172.00
    assert_equal "Test adjustment with target balance", adjustment.note

    # Edit the adjustment
    get edit_organization_account_adjustment_path(@account.organization, @account, adjustment)
    assert_response :success
    assert_select "input[name='adjustment[target_balance]']"

    # Update with new target balance
    patch organization_account_adjustment_path(@account.organization, @account, adjustment), params: {
      adjustment: {
        target_balance: "333.33",  # Update to $333.33
        note: "Updated adjustment"
      }
    }

    assert_redirected_to organization_account_adjustments_path(@account.organization, @account)

    # Verify balance was updated correctly
    @account.reload
    assert_equal 333.33, @account.posted_balance  # Should be exactly $333.33

    # Verify adjustment was updated
    adjustment.reload
    assert_equal 283.33, adjustment.debit_amount  # 333.33 - 50.00 = 283.33
    assert_equal "Updated adjustment", adjustment.note

    # Delete the adjustment
    delete organization_account_adjustment_path(@account.organization, @account, adjustment)
    assert_redirected_to organization_account_adjustments_path(@account.organization, @account)

    # Verify balance was restored to initial
    @account.reload
    assert_equal initial_balance, @account.posted_balance
  end

  private

  def login_as(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end
end
