class TransfersController < ApplicationController
  include OrganizationScoped

  before_action do
    @transfers = current_organization.transfers.includes(:debit_account, :credit_account, :schedule)
    @accounts = current_organization.accounts
  end

  def index
    @pending_transfers = @transfers.pending.order(pending_on: :desc)
    @posted_transfers = @transfers.posted.order(posted_on: :desc)
  end

def new
    @transfer = @transfers.new
    @transfer.pending_on = Date.current
    @accounts = current_organization.accounts

    # Preselect accounts from query params
    @transfer.debit_account_id = params[:debit_account_id] if params[:debit_account_id].present?
    @transfer.credit_account_id = params[:credit_account_id] if params[:credit_account_id].present?
  end

def create
    @transfer = @transfers.new(transfer_params)
    @accounts = current_organization.accounts

    # Set dates based on status selection
    if params[:transfer][:status] == "posted"
      @transfer.posted_on = @transfer.pending_on
      @transfer.state = "posted"
    else
      @transfer.state = "pending"
    end

    if @transfer.save
      redirect_to organization_transfer_path(current_organization, @transfer), notice: "Transfer was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @transfer = @transfers.find(params[:id])
  end

  def edit
    @transfer = @transfers.find(params[:id])
    @accounts = current_organization.accounts
  end

  def update
    @transfer = @transfers.find(params[:id])
    @accounts = current_organization.accounts

    # Set dates based on status selection
    if params[:transfer][:status] == "posted"
      @transfer.posted_on = @transfer.pending_on
      @transfer.state = "posted"
    else
      @transfer.state = "pending"
      @transfer.posted_on = nil
    end

    if @transfer.update(transfer_params)
      redirect_to organization_transfer_path(current_organization, @transfer), notice: "Transfer was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @transfer = @transfers.find(params[:id])
    @transfer.destroy
    redirect_to organization_transfers_path(current_organization), notice: "Transfer was successfully deleted."
  end

  def post
    @transfer = @transfers.find(params[:id])

    if @transfer.post!
      redirect_to organization_transfer_path(current_organization, @transfer), notice: "Transfer was successfully posted."
    else
      redirect_to organization_transfer_path(current_organization, @transfer), alert: "Could not post transfer."
    end
  end

  private

  def transfer_params
    params.expect(transfer: [ :amount, :debit_account_id, :credit_account_id, :pending_on ])
  end
end
