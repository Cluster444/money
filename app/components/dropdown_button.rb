# frozen_string_literal: true

# DropdownButton - Base component for creating dropdown button components
#
# This component provides the common structure and behavior for dropdown buttons.
# Subclasses only need to define their specific content and behavior.
#
# == Required Methods (must be implemented by subclasses):
#
# * current_item - Returns the current item for the dropdown (used to determine if dropdown should render)
# * button_text - Returns the text to display on the button
#
# == Usage Pattern:
#
# class MyDropdown < Components::DropdownButton
#   def initialize(my_params)
#     @my_params = my_params
#   end
#
#   def view_template
#     super do
#       # Your dropdown content here
#       dropdown_list(
#         label: "My Items",
#         items: @my_items,
#         empty_message: "No items available"
#       ) do |item|
#         dropdown_item(href: item_path(item)) { item.name }
#       end
#     end
#   end
#
#   private
#
#   def current_item
#     @my_params[:current_item]
#   end
#
#   def button_text
#     current_item&.name || "Select Item"
#   end
# end
#
# == Available Helper Methods:
#
# * dropdown_item(href: nil, role: "option", **attributes, &block) - Renders a dropdown item with consistent styling
#   - Use href for clickable links
#   - Omit href for empty state items
#   - All attributes are merged with base attributes (caller attributes override)
#   - class: CSS classes are concatenated with base classes
#   - data: Data attributes are merged with base data
#   - Other attributes completely override base attributes
#
# * dropdown_list(label:, items:, empty_message:, **attributes, &item_renderer) - Renders a list container
#   - label: Accessibility label for listbox
#   - items: Array of items to iterate over
#   - empty_message: Message to show when items is empty
#   - item_renderer: Block that receives each item to render
#   - All attributes are merged with base attributes (caller attributes override)
#   - class: CSS classes are concatenated with base classes
#   - data: Data attributes are merged with base data
#   - Other attributes completely override base attributes
#
# * dropdown_list(label:, items:, empty_message:, css_class: nil, data_attrs: nil, **attributes, &item_renderer) - Renders a list container
#   - label: Accessibility label for the listbox
#   - items: Array of items to iterate over
#   - empty_message: Message to show when items is empty
#   - css_class: Additional CSS classes to merge with base classes
#   - data_attrs: Additional data attributes to merge with base data
#   - item_renderer: Block that receives each item to render
#   - Other attributes will override defaults
#
# == JavaScript Controller:
#
# Uses the dropdown-button controller which handles:
# - Toggle open/close functionality
# - Click outside to close
# - Escape key to close and focus button
# - Chevron rotation animation
#
# No custom JavaScript is needed for basic navigation - links work naturally.

class Components::DropdownButton < Components::Base
  def view_template(&block)
    return unless current_item

    div(data: { controller: "dropdown-button" }, class: "relative w-48 m-0") do
      render_button
      render_dropdown(&block)
    end
  end

  private

  def current_item
    raise NotImplementedError, "Subclasses must implement current_item"
  end

  def button_text
    raise NotImplementedError, "Subclasses must implement button_text"
  end

  def render_button
    button(
      data: {
        "dropdown-button-target": "button",
        action: "click->dropdown-button#toggle"
      },
      class: [
        "block w-full py-1 bg-stone-900 rounded",
        "text-stone-100 cursor-pointer transition-all duration-100 ease",
        "flex justify-between items-start"
      ],
      type: "button",
      aria: {
        haspopup: "listbox",
        expanded: "false"
      }
    ) do
      span(class: "flex-1 truncate") { button_text }
      span(class: "text-stone-400 transition-transform duration-300 ease shrink-0 mr-2", data: { "dropdown-button-target": "chevron" }) { "▼" }
    end
  end

  def render_dropdown(&block)
    div(
      class: "hidden data-[open]:block absolute top-8 flex bg-stone-900 w-48 border-2 border-stone-500 shadow-lg",
      data: { "dropdown-button-target": "dropdown" }, &block)
  end

  def dropdown_list(label:, items:, empty_message:, **attributes, &item_renderer)
    base_attrs = {
      class: "mt-1 transform transition-all duration-300 ease",
      role: "listbox",
      aria: { label: label }
    }

    div(**merge_attributes(base_attrs, attributes)) do
      if items.any?
        items.each(&item_renderer)
      else
        dropdown_item { empty_message }
      end
    end
  end

  def dropdown_item(href: nil, role: "option", **attrs, &block)
    base_classes = [ "block w-full p-3 px-4 border-b last:border-b-0 border-stone-500" ]

    base_classes += href ? [
      "no-underline cursor-pointer hover:bg-stone-800"
    ] : [
      "text-stone-400 italic"
    ]

    base_attrs = {
      class: base_classes.join(" "),
      data: { "dropdown-button-target": "option" }
    }

    merged = merge_attributes(base_attrs, attrs)

    if href
      a(href:, role:, **merged, &block)
    else
      div(**merged, &block)
    end
  end

  def merge_attributes(base_attrs, attrs)
    merged = {}

    # Get all unique keys from both hashes
    all_keys = (base_attrs.keys + attrs.keys).uniq

    all_keys.each do |key|
      base_value = base_attrs[key]
      attr_value = attrs[key]

      # If only one side has the key, use that value
      if base_value.nil?
        merged[key] = attr_value
        next
      elsif attr_value.nil?
        merged[key] = base_value
        next
      end

      # Both sides have the key, merge based on type
      case base_value
      when String
        # String concatenation (for CSS classes)
        merged[key] = "#{base_value} #{attr_value}"
      when Array
        # Array concatenation
        merged[key] = base_value + Array(attr_value)
      when Hash
        # Hash merge (attr_value overrides base_value for conflicting keys)
        merged[key] = base_value.merge(attr_value)
      else
        # For other types, attr_value overrides base_value
        merged[key] = attr_value
      end
    end

    merged
  end
end
