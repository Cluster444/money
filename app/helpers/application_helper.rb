module ApplicationHelper
  def format_schedule_frequency(schedule)
    return "Every #{schedule.frequency} #{schedule.period.humanize.pluralize(schedule.frequency)}" if schedule.frequency > 1

    "Every #{schedule.period.humanize}"
  end

  def format_schedule_name_with_amount(schedule)
    if schedule.amount.present? && schedule.period.present?
      amount_str = number_to_currency(schedule.amount)
      if schedule.frequency > 1
        "#{schedule.name} (#{amount_str}/#{schedule.frequency} #{schedule.period.humanize.pluralize(schedule.frequency)})"
      else
        "#{schedule.name} (#{amount_str}/#{schedule.period.humanize})"
      end
    else
      schedule.name
    end
  end

  def money_field(form, method, options = {})
    # Get the value (already in dollars)
    value = form.object.send(method)
    display_value = value.present? ? value.to_s : ""

    # Set default options for money input
    money_options = options.merge(
      value: display_value,
      step: "0.01",
      min: "0",
      class: [ options[:class], "money-input" ].compact.join(" "),
      placeholder: options[:placeholder] || "0.00"
    )

    form.number_field(method, money_options)
  end

  def current_view
    return :accounts if request.path.match?(/\/organizations\/\d+\/accounts/)
    return :transfers if request.path.match?(/\/organizations\/\d+\/transfers/)
    return :schedules if request.path.match?(/\/organizations\/\d+\/schedules/)
    :accounts # default fallback
  end

  def view_items
    [
      { key: :accounts, name: "Accounts", path: -> { organization_accounts_path(current_organization) } },
      { key: :transfers, name: "Transfers", path: -> { organization_transfers_path(current_organization) } },
      { key: :schedules, name: "Schedules", path: -> { organization_schedules_path(current_organization) } }
    ]
  end

  def current_view_item
    view_items.find { |item| item[:key] == current_view }
  end

  def other_view_items
    view_items.reject { |item| item[:key] == current_view }
  end
end
