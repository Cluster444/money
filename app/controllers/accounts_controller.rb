class AccountsController < ApplicationController
  include OrganizationScoped

  def index
    @cash_accounts = current_organization.accounts.cash.includes(:debit_transfers, :credit_transfers, :debit_schedules, :credit_schedules).order(:name)
    @credit_card_accounts = current_organization.accounts.credit_card.includes(:debit_transfers, :credit_transfers, :debit_schedules, :credit_schedules).order(:name)
    @vendor_accounts = current_organization.accounts.vendor.includes(:debit_transfers, :credit_transfers, :debit_schedules, :credit_schedules).order(:name)
  end

  def new
    @account = current_organization.accounts.build
  end

  def create
    @account = current_organization.accounts.build(account_params)

    if @account.save
      redirect_to organization_accounts_path(current_organization), notice: "Account was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @account = current_organization.accounts.find(params[:id])
    @debit_schedules = @account.debit_schedules.order(:name)
    @credit_schedules = @account.credit_schedules.order(:name)
  end

  def edit
    @account = current_organization.accounts.find(params[:id])
  end

  def update
    @account = current_organization.accounts.find(params[:id])

    if @account.update(account_params)
      redirect_to organization_account_path(current_organization, @account), notice: "Account was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def account_params
    params.expect(account: [ :name, :kind, :posted_balance, metadata: {} ])
  end
end
