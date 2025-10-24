class AccountsController < ApplicationController
  include OrganizationScoped

  before_action do
    @accounts = current_organization.accounts
  end

  def index
    @cash_accounts = @accounts.cash.with_transfers.with_schedules.order(:name)
    @credit_card_accounts = @accounts.credit_card.with_transfers.with_schedules.order(:name)
    @vendor_accounts = @accounts.vendor.with_transfers.with_schedules.order(:name)
    @customer_accounts = @accounts.customer.with_transfers.with_schedules.order(:name)
  end

  def new
    @account = build_account_for_kind(params[:kind])
  end

  def create
    @account = build_account_for_kind(params[:account][:kind])
    @account.assign_attributes(account_params)

    if @account.save
      redirect_to organization_accounts_path(current_organization), notice: "Account was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @account = @accounts.find(params[:id])
    @debit_schedules = @account.debit_schedules.order(:name)
    @credit_schedules = @account.credit_schedules.order(:name)
    @transfers = @account.transfers.includes(:debit_account, :credit_account, :schedule).order(pending_on: :desc, posted_on: :desc, created_at: :desc)
  end

  def edit
    @account = @accounts.find(params[:id])
  end

  def update
    @account = @accounts.find(params[:id])

    if @account.update(account_params)
      redirect_to organization_account_path(current_organization, @account), notice: "Account was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def build_account_for_kind(kind)
    case kind
    when "cash", "Account::Cash"
      Account::Cash.new(organization: current_organization)
    when "vendor", "Account::Vendor"
      Account::Vendor.new(organization: current_organization)
    when "credit_card", "Account::CreditCard"
      Account::CreditCard.new(organization: current_organization)
    when "customer", "Account::Customer"
      Account::Customer.new(organization: current_organization)
    else
      Account.new(organization: current_organization)
    end
  end

  def account_params
    base_params = [ :name, :kind, :posted_balance ]

    # Add credit card specific fields if it's a credit card
    # Check both params for new accounts and @account for existing accounts
    if params[:account][:kind] == "credit_card" || params[:account][:kind] == "Account::CreditCard" || (@account&.credit_card?)
      base_params += [ :due_day, :statement_day, :credit_limit ]
    end

    params.expect(account: base_params)
  end
end
