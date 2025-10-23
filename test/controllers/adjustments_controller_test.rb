require "test_helper"

class AdjustmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:lazaro_nixon)
    @account = @user.accounts.cash.first
    login_as @user
  end

  test "should get index" do
    get organization_account_adjustments_url(@account.organization, @account)
    assert_response :success
    assert_select "h1", "Adjustments for #{@account.name}"
    assert_select "a[href=?]", new_organization_account_adjustment_path(@account.organization, @account)
  end

  test "should get new" do
    get new_organization_account_adjustment_url(@account.organization, @account)
    assert_response :success
    assert_select "h1", "New Adjustment for #{@account.name}"
    assert_select "form[action=?]", organization_account_adjustments_path(@account.organization, @account)
    assert_select "textarea[name='adjustment[note]']"
    assert_select "input[name='adjustment[target_balance]']"
  end

  test "should create adjustment to increase balance" do
    initial_balance = @account.posted_balance
    target_balance = initial_balance + 100.00  # Increase by $100

    assert_difference("Adjustment.count", 1) do
      post organization_account_adjustments_url(@account.organization, @account), params: {
        adjustment: {
          target_balance: target_balance.to_s,  # Already in dollars
          note: "Test adjustment to increase balance"
        }
      }
    end

    assert_redirected_to organization_account_adjustments_path(@account.organization, @account)
    assert_equal "Adjustment was successfully created.", flash[:notice]

    @account.reload
    assert_equal target_balance, @account.posted_balance

    adjustment = Adjustment.last
    assert_equal @account, adjustment.account
    assert_equal 100.00, adjustment.debit_amount  # Should create a debit for cash account
    assert_nil adjustment.credit_amount
    assert_equal "Test adjustment to increase balance", adjustment.note
  end

  test "should create adjustment to decrease balance" do
    # First make sure account has enough balance
    @account.update!(debits: 200.00, credits: 0)  # Set balance to $200

    initial_balance = @account.posted_balance
    target_balance = initial_balance - 50.00  # Decrease by $50

    assert_difference("Adjustment.count", 1) do
      post organization_account_adjustments_url(@account.organization, @account), params: {
        adjustment: {
          target_balance: target_balance.to_s,  # Already in dollars
          note: "Test adjustment to decrease balance"
        }
      }
    end

    assert_redirected_to organization_account_adjustments_path(@account.organization, @account)
    assert_equal "Adjustment was successfully created.", flash[:notice]

    @account.reload
    assert_equal target_balance, @account.posted_balance

    adjustment = Adjustment.last
    assert_equal @account, adjustment.account
    assert_equal 50.00, adjustment.credit_amount  # Should create a credit for cash account
    assert_nil adjustment.debit_amount
    assert_equal "Test adjustment to decrease balance", adjustment.note
  end

  test "should not create adjustment without note" do
    assert_no_difference("Adjustment.count") do
      post organization_account_adjustments_url(@account.organization, @account), params: {
        adjustment: {
          target_balance: "100.00"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "form[action=?]", organization_account_adjustments_path(@account.organization, @account)
  end

  test "should not create adjustment without target balance" do
    assert_no_difference("Adjustment.count") do
      post organization_account_adjustments_url(@account.organization, @account), params: {
        adjustment: {
          note: "Test adjustment"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "form[action=?]", organization_account_adjustments_path(@account.organization, @account)
  end

  test "should not create adjustment when target balance equals current balance" do
    current_balance_dollars = (@account.posted_balance / 100.0).to_s

    assert_no_difference("Adjustment.count") do
      post organization_account_adjustments_url(@account.organization, @account), params: {
        adjustment: {
          target_balance: current_balance_dollars,
          note: "Test adjustment with no change"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "form[action=?]", organization_account_adjustments_path(@account.organization, @account)
  end

  test "should get edit" do
    adjustment = @account.adjustments.create!(
      debit_amount: 10000,
      note: "Test adjustment"
    )

    get edit_organization_account_adjustment_url(@account.organization, @account, adjustment)
    assert_response :success
    assert_select "h1", "Edit Adjustment for #{@account.name}"
    assert_select "form[action=?]", organization_account_adjustment_path(@account.organization, @account, adjustment)
    assert_select "textarea[name='adjustment[note]']", "Test adjustment"
    assert_select "input[name='adjustment[target_balance]']"
  end

  test "should update adjustment" do
    # Create initial adjustment
    @account.update!(debits: 100.00, credits: 0)  # Start with $100 balance
    adjustment = @account.adjustments.create!(
      debit_amount: 50.00,
      note: "Original note"
    )
    initial_balance = @account.posted_balance  # Should be $150

    # Update to target $200 balance
    patch organization_account_adjustment_url(@account.organization, @account, adjustment), params: {
      adjustment: {
        target_balance: "200.00",  # $200.00 in dollars
        note: "Updated note"
      }
    }

    assert_redirected_to organization_account_adjustments_path(@account.organization, @account)
    assert_equal "Adjustment was successfully updated.", flash[:notice]

    @account.reload
    assert_equal 200.00, @account.posted_balance  # Should be $200

    adjustment.reload
    assert_equal 100.00, adjustment.debit_amount  # Should be $100 debit
    assert_nil adjustment.credit_amount
    assert_equal "Updated note", adjustment.note
  end

  test "should update adjustment to decrease balance" do
    # Create initial adjustment
    @account.update!(debits: 200.00, credits: 0)  # Start with $200 balance
    adjustment = @account.adjustments.create!(
      debit_amount: 100.00,
      note: "Original note"
    )
    initial_balance = @account.posted_balance  # Should be $300

    # Update to target $150 balance
    patch organization_account_adjustment_url(@account.organization, @account, adjustment), params: {
      adjustment: {
        target_balance: "150.00",  # $150.00 in dollars
        note: "Updated note"
      }
    }

    assert_redirected_to organization_account_adjustments_path(@account.organization, @account)
    assert_equal "Adjustment was successfully updated.", flash[:notice]

    @account.reload
    assert_equal 150.00, @account.posted_balance  # Should be $150

    adjustment.reload
    assert_equal 50.00, adjustment.credit_amount  # Should be $50 credit (decrease)
    assert_nil adjustment.debit_amount
    assert_equal "Updated note", adjustment.note
  end

  test "should not update adjustment with invalid data" do
    adjustment = @account.adjustments.create!(
      debit_amount: 100.00,
      note: "Original note"
    )

    patch organization_account_adjustment_url(@account.organization, @account, adjustment), params: {
      adjustment: {
        target_balance: "",
        note: ""
      }
    }

    assert_response :unprocessable_entity

    adjustment.reload
    assert_equal 100.00, adjustment.debit_amount
    assert_equal "Original note", adjustment.note
  end

  test "should destroy adjustment" do
    adjustment = @account.adjustments.create!(
      debit_amount: 10000,
      note: "Test adjustment"
    )
    initial_balance = @account.posted_balance

    assert_difference("Adjustment.count", -1) do
      delete organization_account_adjustment_url(@account.organization, @account, adjustment)
    end

    assert_redirected_to organization_account_adjustments_path(@account.organization, @account)
    assert_equal "Adjustment was successfully deleted.", flash[:notice]

    @account.reload
    assert_equal initial_balance - 10000, @account.posted_balance
  end

  test "should not access adjustments for other user's account" do
    other_user = User.create!(
      first_name: "Other",
      last_name: "User",
      email_address: "other@example.com",
      password: "password123"
    )
    organization = other_user.organizations.create!(name: "Other Organization")
    other_account = organization.accounts.create!(
      name: "Other User Account",
      kind: "Account::Cash"
    )

    get new_organization_account_adjustment_url(other_account.organization, other_account)
    assert_response :not_found

    post organization_account_adjustments_url(other_account.organization, other_account), params: {
      adjustment: {
        target_balance: "100.00",
        note: "Test adjustment"
      }
    }
    assert_response :not_found

    # Clean up
    other_user.organizations.each { |org| org.accounts.destroy_all }
    other_user.organizations.destroy_all
    other_user.destroy
  end

  test "should not access other user's adjustment" do
    other_user = User.create!(
      first_name: "Other",
      last_name: "User",
      email_address: "other@example.com",
      password: "password123"
    )
    organization = other_user.organizations.create!(name: "Other Organization")
    other_account = organization.accounts.create!(
      name: "Other User Account",
      kind: "Account::Cash"
    )
    other_adjustment = other_account.adjustments.create!(
      credit_amount: 10000,
      note: "Other adjustment"
    )

    get edit_organization_account_adjustment_url(other_account.organization, other_account, other_adjustment)
    assert_response :not_found

    patch organization_account_adjustment_url(other_account.organization, other_account, other_adjustment), params: {
      adjustment: {
        note: "Updated note"
      }
    }
    assert_response :not_found

    delete organization_account_adjustment_url(other_account.organization, other_account, other_adjustment)
    assert_response :not_found

    # Clean up
    other_user.organizations.each { |org| org.accounts.destroy_all }
    other_user.organizations.destroy_all
    other_user.destroy
  end

  test "should convert decimal dollars to cents correctly" do
    initial_balance = @account.posted_balance
    target_balance = initial_balance + 12345  # Add $123.45

    assert_difference("Adjustment.count", 1) do
      post organization_account_adjustments_url(@account.organization, @account), params: {
        adjustment: {
          target_balance: "123.45",  # $123.45
          note: "Decimal amount test"
        }
      }
    end

    @account.reload
    assert_equal 123.45, @account.posted_balance  # Should be exactly $123.45

    adjustment = Adjustment.last
    assert_equal 123.45, adjustment.debit_amount  # Should create debit for cash account
  end

  test "should handle rounding correctly" do
    initial_balance = @account.posted_balance

    assert_difference("Adjustment.count", 1) do
      post organization_account_adjustments_url(@account.organization, @account), params: {
        adjustment: {
          target_balance: "10.005",  # Should round to 10.01
          note: "Rounding test"
        }
      }
    end

    @account.reload
    assert_equal 10.01, @account.posted_balance  # 10.005 rounds to 10.01

    adjustment = Adjustment.last
    assert_equal 10.01, adjustment.debit_amount
  end

  private

  def login_as(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end
end
