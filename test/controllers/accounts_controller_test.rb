require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:lazaro_nixon)
    login_as @user
  end

  test "should get index with no accounts" do
    @user.organizations.joins(:accounts).each { |org| org.accounts.destroy_all }

    get organization_accounts_url(@user.organizations.first)
    assert_response :success
    assert_select "h1", "Accounts"
    assert_select ".page__empty", "No accounts yet. Create your first account to get started."
  end

  test "should get index with cash accounts only" do
    @user.organizations.joins(:accounts).where.not(accounts: { kind: "cash" }).each { |org| org.accounts.where.not(kind: "cash").destroy_all }

    get organization_accounts_url(@user.organizations.first)
    assert_response :success
    assert_select "h1", "Accounts"
    assert_select ".page__section-header", "Cash"
    assert_select ".page__section-header", { text: "Credit Cards", count: 0 }
    assert_select ".page__section-header", { text: "Vendors", count: 0 }
    assert_select ".page__empty", count: 0
  end

  test "should get index with credit card accounts only" do
    @user.accounts.where.not(kind: "credit_card").destroy_all

    get organization_accounts_url(@user.organizations.first)
    assert_response :success
    assert_select "h1", "Accounts"
    assert_select ".page__section-header", { text: "Cash", count: 0 }
    assert_select ".page__section-header", "Credit Cards"
    assert_select ".page__section-header", { text: "Vendors", count: 0 }
    assert_select ".page__empty", count: 0
  end

  test "should get index with vendor accounts only" do
    @user.accounts.where.not(kind: "vendor").destroy_all

    get organization_accounts_url(@user.organizations.first)
    assert_response :success
    assert_select "h1", "Accounts"
    assert_select ".page__section-header", { text: "Cash", count: 0 }
    assert_select ".page__section-header", { text: "Credit Cards", count: 0 }
    assert_select ".page__section-header", "Vendors"
    assert_select ".page__empty", count: 0
  end

  test "should get index with all account types" do
    get organization_accounts_url(@user.organizations.first)
    assert_response :success
    assert_select "h1", "Accounts"
    assert_select ".page__section-header", "Cash"
    assert_select ".page__section-header", "Credit Cards"
    assert_select ".page__section-header", "Vendors"
    assert_select ".page__empty", count: 0
  end

  test "should display account balances correctly" do
    get organization_accounts_url(@user.organizations.first)

    @user.accounts.each do |account|
      assert_select ".accounts-index__card-name", account.name
      assert_select ".accounts-index__balance-value", text: /\$\d+\.\d{2}/
    end
  end

  test "should order accounts alphabetically within each section" do
    get organization_accounts_url(@user.organizations.first)

    # Extract account names from the response in order and decode HTML entities
    account_names = response.body.scan(/class="accounts-index__card-name">(.*?)<\/h3>/m).flatten.map { |name| CGI.unescapeHTML(name) }

    # Get expected ordered lists
    cash_names = @user.accounts.cash.order(:name).pluck(:name)
    credit_card_names = @user.accounts.credit_card.order(:name).pluck(:name)
    vendor_names = @user.accounts.vendor.order(:name).pluck(:name)

    # Check that the order matches (sections appear in order: cash, credit cards, vendors)
    expected_order = cash_names + credit_card_names + vendor_names
    assert_equal expected_order, account_names
  end

  test "should include new account link" do
    get organization_accounts_url(@user.organizations.first)
    assert_response :success
    assert_select "a[href=?]", new_organization_account_path(@user.organizations.first), text: "New"
  end

  test "should get new" do
    get new_organization_account_url(@user.organizations.first)
    assert_response :success
    assert_select "h1", "New Account"
    assert_select "form[action=?]", organization_accounts_path(@user.organizations.first)
    assert_select "select[name='account[kind]']"
    assert_select "input[name='account[name]']"
  end

  test "should create account" do
    assert_difference("Account.count", 1) do
      post organization_accounts_url(@user.organizations.first), params: { account: { name: "Test Account", kind: "cash" } }
    end

    assert_redirected_to organization_accounts_url(@user.organizations.first)
    assert_equal "Account was successfully created.", flash[:notice]

    created_account = Account.last
    assert_equal "Test Account", created_account.name
    assert_equal "cash", created_account.kind
    assert_equal @user, created_account.user
  end

  test "should not create account with invalid data" do
    assert_no_difference("Account.count") do
      post organization_accounts_url(@user.organizations.first), params: { account: { name: "", kind: "cash" } }
    end

    assert_response :unprocessable_entity
    assert_select "form[action=?]", organization_accounts_path(@user.organizations.first)
  end

  test "should show account" do
    account = @user.accounts.cash.first

    get organization_account_url(account.organization, account)
    assert_response :success
    assert_select "h1", account.name
    assert_select ".accounts-show__balance-value", text: /\$\d+\.\d{2}/
  end

  test "should not show account from other user" do
    # Create another user and account for testing access control
    other_user = User.create!(
      first_name: "Other",
      last_name: "User",
      email_address: "other@example.com",
      password: "password123"
    )
    organization = other_user.organizations.create!(name: "Other Organization")
    other_account = organization.accounts.create!(
      name: "Other User Account",
      kind: "cash"
    )

    get organization_account_url(other_account.organization, other_account)
    assert_response :not_found

    # Clean up
    other_user.organizations.each { |org| org.accounts.destroy_all }
    other_user.organizations.destroy_all
    other_user.destroy
  end

  test "should get edit" do
    account = @user.accounts.cash.first

    get edit_organization_account_url(account.organization, account)
    assert_response :success
    assert_select "h1", "Edit Account"
    assert_select "form[action=?]", organization_account_path(account.organization, account)
    assert_select "input[name='account[name]'][value=?]", account.name
    assert_select "select[name='account[kind]']"
  end

  test "should update account" do
    account = @user.accounts.cash.first

    patch organization_account_url(account.organization, account), params: { account: { name: "Updated Account Name" } }
    assert_redirected_to organization_account_url(account.organization, account)
    assert_equal "Account was successfully updated.", flash[:notice]

    account.reload
    assert_equal "Updated Account Name", account.name
  end

  test "should not update account with invalid data" do
    account = @user.accounts.cash.first
    original_name = account.name

    patch organization_account_url(account.organization, account), params: { account: { name: "" } }
    assert_response :unprocessable_entity

    account.reload
    assert_equal original_name, account.name
  end

  test "should create credit card account" do
    assert_difference("Account.count", 1) do
      post organization_accounts_url(@user.organizations.first), params: {
        account: {
          name: "Test Credit Card",
          kind: "credit_card"
        }
      }
    end

    assert_redirected_to organization_accounts_url(@user.organizations.first)

    created_account = Account.last
    assert_equal "Test Credit Card", created_account.name
    assert_equal "credit_card", created_account.kind
  end

  test "should show credit card account with payment schedule" do
    credit_card = accounts(:lazaro_credit_card)

    get organization_account_url(credit_card.organization, credit_card)
    assert_response :success
    assert_select "h1", credit_card.name
    assert_select ".accounts-show__kind--credit_card", "Credit card"

    # Check that metadata is displayed
    assert_select ".accounts-show__metadata" do
      assert_select ".accounts-show__metadata-key", "Due Day:"
      assert_select ".accounts-show__metadata-value", "15"
      assert_select ".accounts-show__metadata-key", "Statement Day:"
      assert_select ".accounts-show__metadata-value", "1"
    end

    # Check that debit schedules section is present (credit card payment schedule)
    assert_select "h2", "Debit Schedules"
    assert_select ".accounts-show__schedule-card" do
      assert_select ".accounts-show__schedule-name", "Payment for Lazaro's Credit Card"
      # Schedule should have no amount displayed (amount is nil)
      assert_select ".accounts-show__schedule-amount", count: 0
    end
  end

  test "should create payment schedule when creating credit card with metadata" do
    # Create a cash account first (required for schedule creation)
    cash_account = Account.create!(
      name: "Test Cash Account for Schedule",
      kind: "cash",
      user: @user
    )

    assert_difference("Schedule.count", 1) do
      # Create credit card directly with metadata (controller doesn't support metadata yet)
      credit_card = Account.create!(
        name: "Test Credit Card with Schedule",
        kind: "credit_card",
        user: @user,
        metadata: { "due_day": 15, "statement_day": 1 }
      )
    end

    created_schedule = Schedule.last
    assert_equal "Payment for Test Credit Card with Schedule", created_schedule.name
    assert_equal "month", created_schedule.period
    assert_equal 1, created_schedule.frequency
  end

  test "credit card schedule creation works with frequency" do
    # Create a cash account first (required for schedule creation)
    cash_account = Account.create!(
      name: "Test Cash Account",
      kind: "cash",
      user: @user
    )

    # Create a credit card account with metadata that should trigger schedule creation
    credit_card = Account.create!(
      name: "Test Credit Card",
      kind: "credit_card",
      user: @user,
      metadata: { "due_day": 15, "statement_day": 1 }
    )

    # Check if schedule was created
    schedule = credit_card.debit_schedules.first
    assert_not_nil schedule, "Payment schedule should be created for credit card"

    # Check that the schedule has period and frequency (the fix)
    assert_equal "month", schedule.period
    assert_equal 1, schedule.frequency, "Schedule should have frequency of 1"

    # Should be able to calculate next materialized date without error
    assert_nothing_raised do
      next_date = schedule.next_materialized_on
      assert_not_nil next_date, "Should have a next materialized date"
    end
  end

  test "credit card payment schedule is set for day before statement date" do
    # Create a cash account first (required for schedule creation)
    cash_account = Account.create!(
      name: "Test Cash Account",
      kind: "cash",
      user: @user
    )

    # Create a credit card with statement day 15 and due day 25
    credit_card = Account.create!(
      name: "Test Credit Card",
      kind: "credit_card",
      user: @user,
      metadata: { "due_day": 25, "statement_day": 15 }
    )

    schedule = credit_card.debit_schedules.first
    assert_not_nil schedule, "Payment schedule should be created"

    # The payment should be scheduled for 1 day before statement date (14th)
    expected_payment_date = credit_card.next_payment_date
    assert_equal expected_payment_date, schedule.starts_on

    # Verify it's actually 1 day before statement date
    expected_day_before_statement = credit_card.next_statement_date - 1.day
    assert_equal expected_day_before_statement, expected_payment_date
  end

  private

  def login_as(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end
end
