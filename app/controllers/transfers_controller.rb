class TransfersController < ApplicationController
  include OrganizationScoped

  def index
    @transfers = current_organization.transfers.includes(:debit_account, :credit_account).order(created_at: :desc)
  end

  def new
    @transfer = current_organization.transfers.build
  end

  def create
    @transfer = current_organization.transfers.build(transfer_params)

    if @transfer.save
      redirect_to organization_transfers_path(current_organization), notice: "Transfer was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @transfer = current_organization.transfers.find(params[:id])
  end

  def edit
    @transfer = current_organization.transfers.find(params[:id])
  end

  def update
    @transfer = current_organization.transfers.find(params[:id])

    if @transfer.update(transfer_params)
      redirect_to organization_transfer_path(current_organization, @transfer), notice: "Transfer was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @transfer = current_organization.transfers.find(params[:id])
    @transfer.destroy
    redirect_to organization_transfers_path(current_organization), notice: "Transfer was successfully deleted."
  end

  private

  def transfer_params
    params.expect(transfer: [ :debit_account_id, :credit_account_id, :amount, :date, :note ])
  end
end
