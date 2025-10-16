class HomeController < ApplicationController
  def index
    organizations = Current.user.organizations.order(:name)

    if organizations.empty?
      redirect_to new_organization_path
    elsif organizations.count == 1
      redirect_to organization_accounts_path(organizations.first)
    else
      redirect_to organizations_path
    end
  end
end
