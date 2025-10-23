require "test_helper"

class TransferMoneyFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:lazaro_nixon)
    @checking_account = accounts(:lazaro_checking)
    @savings_account = accounts(:lazaro_savings)

    # Set initial balances for testing - checking needs enough balance for transfer
    @checking_account.update!(debits: 100.00, credits: 0.00)
    @savings_account.update!(debits: 50.00, credits: 0.00)
  end

  test "transfer money from checking to savings using Out button" do
    # Sign in user
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    follow_redirect!
    follow_redirect!
    assert_response :success

    # Visit accounts index
    get organization_accounts_path(@user.organizations.first)
    assert_response :success

    # Assert there is an In and Out button within the checking cash account
    assert_select "##{dom_id(@checking_account)} .accounts-index__actions" do
      assert_select "a[href*='debit_account_id=#{@checking_account.id}']", text: "In"
      assert_select "a[href*='credit_account_id=#{@checking_account.id}']", text: "Out"
    end

    # Click on the Out button
    get new_organization_transfer_path(@user.organizations.first, credit_account_id: @checking_account.id)
    assert_response :success

    # Assert that the Credit account is selected and is the name of the account we clicked on
    assert_select "select#transfer_credit_account_id option[selected][value='#{@checking_account.id}']"

    # Assert that the Debit account is not selected
    assert_select "select#transfer_debit_account_id option[selected]", count: 0

    # Enter an amount, set the debit account to the Savings cash account, and select posted in the state
    transfer_amount = "25.00"
    post organization_transfers_path(@user.organizations.first), params: {
      transfer: {
        amount: transfer_amount,
        credit_account_id: @checking_account.id,
        debit_account_id: @savings_account.id,
        status: "posted"
      }
    }

    # Assert we redirect to a transfer show page
    assert_redirected_to organization_transfer_path(@user.organizations.first, Transfer.last)
    follow_redirect!
    assert_response :success

    # Assert that the details of the transfer make sense, look at the template for what it's supposed to show
    transfer = Transfer.last
    assert_equal transfer_amount.to_d, transfer.amount
    assert_equal @checking_account, transfer.credit_account
    assert_equal @savings_account, transfer.debit_account
    assert_equal "posted", transfer.state

    # Assert transfer details are displayed correctly
    assert_select ".transfer-show__amount-value", text: /\$25\.00/
    assert_select ".transfer-show__state--posted", text: "Posted"
    assert_select ".transfer-show__value", text: @checking_account.name
    assert_select ".transfer-show__value", text: @savings_account.name

    # Visit the accounts index for our org
    get organization_accounts_path(@user.organizations.first)
    assert_response :success

    # Assert that the posted balance has dropped on the checking account and increased in the savings account
    @checking_account.reload
    @savings_account.reload

    # Checking account should have decreased balance (money went out)
    # Checking: 100 debits - 25 credits = 75 balance
    assert_select "##{dom_id(@checking_account)}" do
      assert_select ".accounts-index__balance-value", text: /\$75\.00/
    end

    # Savings account should have increased balance (money came in)
    # Savings: 50 debits + 25 debits = 75 debits, 0 credits = 75 balance
    assert_select "##{dom_id(@savings_account)}" do
      assert_select ".accounts-index__balance-value", text: /\$75\.00/
    end
  end
end
