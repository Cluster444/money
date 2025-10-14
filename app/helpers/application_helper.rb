module ApplicationHelper
  def format_schedule_frequency(schedule)
    return "Every #{schedule.frequency} #{schedule.period.humanize.pluralize(schedule.frequency)}" if schedule.frequency > 1

    "Every #{schedule.period.humanize}"
  end

  def money_field(form, method, options = {})
    # Convert cents to dollars for display
    value = form.object.send(method)
    display_value = value.present? ? (value / 100.0).to_s : ""

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

  def cents_to_dollars(cents)
    return nil if cents.nil?
    cents / 100.0
  end

  def dollars_to_cents(dollars)
    return nil if dollars.nil?
    (BigDecimal(dollars.to_s) * 100).round.to_i
  end
end
