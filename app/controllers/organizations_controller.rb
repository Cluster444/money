class OrganizationsController < ApplicationController
  def index
    @organizations = Current.user.organizations.order(:name)
  end

  def new
    @organization = Current.user.organizations.build
  end

  def create
    @organization = Current.user.organizations.build(organization_params)

    if @organization.save
      redirect_to organization_accounts_path(@organization), notice: "Organization was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @organization = Current.user.organizations.find(params[:id])
  end

  def update
    @organization = Current.user.organizations.find(params[:id])

    if @organization.update(organization_params)
      redirect_to organization_accounts_path(@organization), notice: "Organization was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def organization_params
    params.expect(organization: [ :name ])
  end
end
