module ButtonHelper
  def new_button(path, options = {})
    link_to "New", path, {
      class: "btn btn--primary"
    }.merge(options)
  end

  def back_button(path, text = nil, options = {})
    text ||= "← Back"
    link_to text, path, {
      class: "btn btn--secondary"
    }.merge(options)
  end

  def edit_button(path, options = {})
    link_to "Edit", path, {
      class: "btn btn--secondary btn--small"
    }.merge(options)
  end

  def delete_button(path, options = {})
    default_options = {
      class: "btn btn--danger btn--small",
      data: {
        turbo_method: :delete,
        turbo_confirm: "Are you sure?"
      }
    }

    # Deep merge the data hash to preserve turbo_method when custom data is provided
    if options[:data]
      options = options.dup
      options[:data] = default_options[:data].merge(options[:data])
    end

    link_to "Delete", path, default_options.merge(options)
  end

  def cancel_button(path, options = {})
    link_to "Cancel", path, {
      class: "btn btn--secondary"
    }.merge(options)
  end
end
