module OrganizationScoped
  extend ActiveSupport::Concern

  included do
    before_action :load_organization
    helper_method :current_organization, :other_organizations
  end

  private

  def load_organization
    @organization = Current.user.organizations.find(params[:organization_id])
  end

  def current_organization
    @organization
  end

  def other_organizations
    Current.user.organizations.where.not(id: current_organization.id).order(:name)
  end
end
