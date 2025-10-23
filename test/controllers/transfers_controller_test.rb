require "test_helper"

class TransfersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:lazaro_nixon)
    @organization = organizations(:lazaro_personal)
    @transfer = transfers(:pending_transfer)

    login_as @user
  end

  test "should get index" do
    get organization_transfers_url(@organization)
    assert_response :success
  end

  test "should get new" do
    get new_organization_transfer_url(@organization)
    assert_response :success
  end

  test "should create pending transfer" do
    assert_difference("Transfer.count") do
      post organization_transfers_url(@organization), params: {
        transfer: {
          amount: "50.00",
          debit_account_id: accounts(:lazaro_checking).id,
          credit_account_id: accounts(:expense_account).id,
          status: "pending"
        }
      }
    end

    transfer = Transfer.last
    assert_equal "pending", transfer.state
    assert_equal Date.current, transfer.pending_on
    assert_nil transfer.posted_on
    assert_equal 50.0, transfer.amount  # Should be returned as dollars
    assert_redirected_to organization_transfer_url(@organization, transfer)
  end

  test "should create posted transfer" do
    assert_difference("Transfer.count") do
      post organization_transfers_url(@organization), params: {
        transfer: {
          amount: "50.00",
          debit_account_id: accounts(:lazaro_checking).id,
          credit_account_id: accounts(:expense_account).id,
          status: "posted"
        }
      }
    end

    transfer = Transfer.last
    assert_equal "posted", transfer.state
    assert_equal Date.current, transfer.pending_on
    assert_equal Date.current, transfer.posted_on
    assert_equal 50.0, transfer.amount  # Should be returned as dollars
    assert_redirected_to organization_transfer_url(@organization, transfer)
  end

  test "should show transfer" do
    get organization_transfer_url(@organization, @transfer)
    assert_response :success
  end

  test "should get edit" do
    get edit_organization_transfer_url(@organization, @transfer)
    assert_response :success
  end

  test "should update transfer" do
    patch organization_transfer_url(@organization, @transfer), params: {
      transfer: {
        amount: "60.00",
        debit_account_id: accounts(:lazaro_checking).id,
        credit_account_id: accounts(:expense_account).id
      }
    }
    assert_redirected_to organization_transfer_url(@organization, @transfer)
    @transfer.reload
    assert_equal 60.0, @transfer.amount
  end

  test "should destroy transfer" do
    assert_difference("Transfer.count", -1) do
      delete organization_transfer_url(@organization, @transfer)
    end

    assert_redirected_to organization_transfers_url(@organization)
  end

  test "should post pending transfer" do
    patch post_organization_transfer_url(@organization, @transfer)
    assert_redirected_to organization_transfer_url(@organization, @transfer)
    @transfer.reload
    assert @transfer.posted?
  end

  test "should handle decimal amounts correctly" do
    assert_difference("Transfer.count") do
      post organization_transfers_url(@organization), params: {
        transfer: {
          amount: "123.45",
          debit_account_id: accounts(:lazaro_checking).id,
          credit_account_id: accounts(:expense_account).id,
          status: "pending"
        }
      }
    end

    transfer = Transfer.last
    assert_equal 123.45, transfer.amount
    # Verify it's stored as cents in the database
    assert_equal 12345, transfer.read_attribute(:amount)
  end

  test "should create posted transfer and update account balances" do
    to_account = accounts(:lazaro_checking)      # Money goes TO this account (debit_account)
    from_account = accounts(:expense_account) # Money comes FROM this account (credit_account)

    # Store initial balances
    initial_to_debits = to_account.debits
    initial_from_credits = from_account.credits

    assert_difference("Transfer.count") do
      post organization_transfers_url(@organization), params: {
        transfer: {
          amount: "75.00",
          debit_account_id: to_account.id,     # TO account gets debited
          credit_account_id: from_account.id,  # FROM account gets credited
          status: "posted"
        }
      }
    end

    transfer = Transfer.last
    assert_equal "posted", transfer.state
    assert_equal 75.0, transfer.amount

    # Reload accounts to get updated values
    to_account.reload
    from_account.reload

    # Assert that account balances were updated correctly
    # TO account should get DEBITS (money receiving)
    assert_equal initial_to_debits + 75.0, to_account.debits, "TO account debits should increase by transfer amount"
    # FROM account should get CREDITS (money leaving)
    assert_equal initial_from_credits + 75.0, from_account.credits, "FROM account credits should increase by transfer amount"
  end

  private

  def login_as(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end
end
