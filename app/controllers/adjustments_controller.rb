class AdjustmentsController < ApplicationController
  before_action :set_account
  before_action :set_adjustment, only: [ :edit, :update, :destroy ]

  def index
    @adjustments = @account.adjustments.order(created_at: :desc)
  end

  def new
    @adjustment = @account.adjustments.build
  end

  def create
    @adjustment = @account.adjustments.build(adjustment_params)

    if @adjustment.save
      redirect_to account_adjustments_path(@account), notice: "Adjustment was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @adjustment.update(adjustment_params)
      redirect_to account_adjustments_path(@account), notice: "Adjustment was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @adjustment.destroy
    redirect_to account_adjustments_path(@account), notice: "Adjustment was successfully deleted."
  end

  private

  def set_account
    @account = Current.user.accounts.find(params[:account_id])
  end

  def set_adjustment
    @adjustment = @account.adjustments.find(params[:id])
  end

  def adjustment_params
    params.require(:adjustment).permit(:target_balance, :note).tap do |adjustment_params|
      if adjustment_params[:target_balance].present?
        target_balance_cents = dollars_to_cents(adjustment_params[:target_balance])

        # For updates, we need to calculate based on what the balance would be without this adjustment
        if @adjustment&.persisted?
          # Remove the effect of the current adjustment to get the base balance
          base_balance = @account.posted_balance - @adjustment.net_effect
          current_balance = base_balance
        else
          current_balance = @account.posted_balance
        end

        # Calculate the difference and determine if it's a debit or credit
        difference = target_balance_cents - current_balance

        if difference > 0
          # Need to increase balance - for cash accounts this means debit
          if @account.cash? || @account.vendor?
            adjustment_params[:debit_amount] = difference
            adjustment_params[:credit_amount] = nil
          else # credit card
            adjustment_params[:credit_amount] = difference
            adjustment_params[:debit_amount] = nil
          end
        elsif difference < 0
          # Need to decrease balance - for cash accounts this means credit
          if @account.cash? || @account.vendor?
            adjustment_params[:credit_amount] = difference.abs
            adjustment_params[:debit_amount] = nil
          else # credit card
            adjustment_params[:debit_amount] = difference.abs
            adjustment_params[:credit_amount] = nil
          end
        else
          # No adjustment needed
          adjustment_params[:credit_amount] = nil
          adjustment_params[:debit_amount] = nil
        end

        # Remove target_balance as it's not a model attribute
        adjustment_params.delete(:target_balance)
      end
    end
  end

  def dollars_to_cents(dollars)
    return nil if dollars.nil?
    (BigDecimal(dollars.to_s) * 100).round.to_i
  end
end
