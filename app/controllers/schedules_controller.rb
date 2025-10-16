class SchedulesController < ApplicationController
  include OrganizationScoped

  def index
    @schedules = current_organization.schedules.includes(:debit_account, :credit_account).order(:name)
  end

  def new
    @schedule = current_organization.schedules.build
  end

  def create
    @schedule = current_organization.schedules.build(schedule_params)

    if @schedule.save
      redirect_to organization_schedules_path(current_organization), notice: "Schedule was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @schedule = current_organization.schedules.find(params[:id])
  end

  def edit
    @schedule = current_organization.schedules.find(params[:id])
  end

  def update
    @schedule = current_organization.schedules.find(params[:id])

    if @schedule.update(schedule_params)
      redirect_to organization_schedule_path(current_organization, @schedule), notice: "Schedule was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @schedule = current_organization.schedules.find(params[:id])
    @schedule.destroy
    redirect_to organization_schedules_path(current_organization), notice: "Schedule was successfully deleted."
  end

  private

  def schedule_params
    params.expect(schedule: [ :name, :debit_account_id, :credit_account_id, :amount, :frequency, :start_date, :end_date, :note ])
  end
end
