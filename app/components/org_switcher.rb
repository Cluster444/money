# frozen_string_literal: true

class Components::OrgSwitcher < Components::DropdownButton
  def initialize(current_organization:, other_organizations:)
    @current_organization = current_organization
    @other_organizations = other_organizations
  end

  def view_template
    super do
      render_new_org_link
      render_list
    end
  end

  private

  def current_item
    @current_organization
  end

  def button_text
    @current_organization.name
  end

  def render_new_org_link
    dropdown_item(href: new_organization_path) do
      "+ New Organization"
    end
  end

  def render_list
    dropdown_list(
      label: "Organizations",
      items: @other_organizations,
      empty_message: "No other organizations"
    ) do |org|
      render_organization_option(org)
    end
  end

  def render_organization_option(org)
    dropdown_item(href: Rails.application.routes.url_helpers.organization_accounts_path(org)) do
      org.name
    end
  end
end
