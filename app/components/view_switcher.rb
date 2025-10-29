# frozen_string_literal: true

class Components::ViewSwitcher < Components::DropdownButton
  def initialize(current_organization:, current_view:)
    @current_organization = current_organization
    @current_view = current_view
    @view_items = [
      { key: :accounts, name: "Accounts", path: -> { Rails.application.routes.url_helpers.organization_accounts_path(@current_organization) } },
      { key: :transfers, name: "Transfers", path: -> { Rails.application.routes.url_helpers.organization_transfers_path(@current_organization) } },
      { key: :schedules, name: "Schedules", path: -> { Rails.application.routes.url_helpers.organization_schedules_path(@current_organization) } }
    ]
  end

  def view_template
    super do
      render_list
    end
  end

  private

  def current_item
    @current_organization
  end

  def button_text
    current_view_item[:name]
  end

  def current_view_item
    @view_items.find { |item| item[:key] == @current_view }
  end

  def other_view_items
    @view_items.reject { |item| item[:key] == @current_view }
  end

  def render_list
    dropdown_list(
      label: "Views",
      items: other_view_items,
      empty_message: "No other views"
    ) do |item|
      render_view_option(item)
    end
  end

  def render_view_option(item)
    dropdown_item(href: item[:path].call) do
      item[:name]
    end
  end
end
