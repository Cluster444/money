class AccountsController < ApplicationController
  def index
    @cash_accounts = Current.user.accounts.cash.order(:name)
    @credit_card_accounts = Current.user.accounts.credit_card.order(:name)
    @vendor_accounts = Current.user.accounts.vendor.order(:name)
  end

  def new
    @account = Current.user.accounts.build
  end

  def create
    @account = Current.user.accounts.build(account_params)

    if @account.save
      redirect_to accounts_path, notice: "Account was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @account = Current.user.accounts.find(params[:id])
    @debit_schedules = @account.debit_schedules.order(:name)
    @credit_schedules = @account.credit_schedules.order(:name)
  end

  def edit
    @account = Current.user.accounts.find(params[:id])
  end

  def update
    @account = Current.user.accounts.find(params[:id])

    if @account.update(account_params)
      redirect_to @account, notice: "Account was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def account_params
    params.expect(account: [ :name, :kind, metadata: {} ])
  end
end
