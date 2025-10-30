# frozen_string_literal: true

# TabPanel - A reusable tab component for organizing content into switchable tabs
#
# This component provides a tabbed interface with client-side switching functionality.
# It's designed to be flexible and can handle different types of content.
#
# == Usage:
#
# In ERB template:
#   <div class="tab-panel" data-controller="tab" data-tab-default-value="schedules">
#     <nav class="tab-panel__navigation">
#       <button type="button" class="tab-panel__button"
#               data-action="click->tab#switch"
#               data-tab-target="button"
#               data-tag="schedules">
#         Schedules
#       </button>
#       <button type="button" class="tab-panel__button"
#               data-action="click->tab#switch"
#               data-tab-target="button"
#               data-tag="transfers">
#         Transfers
#       </button>
#     </nav>
#
#     <div class="tab-panel__content-wrapper">
#       <div class="tab-panel__content"
#            id="tab-schedules"
#            data-tab-target="content"
#            data-tag="schedules">
#         <!-- Schedules content -->
#       </div>
#       <div class="tab-panel__content"
#            id="tab-transfers"
#            data-tab-target="content"
#            data-tag="transfers"
#            style="display: none;">
#         <!-- Transfers content -->
#       </div>
#     </div>
#   </div>
#
# == JavaScript Controller:
#
# Uses the tab controller which handles:
# - Tab switching via button clicks
# - Active state management for buttons and content
# - Initial tab activation based on data-tab-default-value
#
# == CSS Classes:
#
# - .tab-panel: Main container
# - .tab-panel__navigation: Tab buttons container
# - .tab-panel__button: Individual tab button
# - .tab-panel__button--active: Active tab button state
# - .tab-panel__content-wrapper: Content area container
# - .tab-panel__content: Individual tab content panel

class Components::TabPanel < Components::Base
  # This component is currently implemented as a pattern/guide
  # rather than a reusable Phlex component due to ERB complexity
  # See usage documentation above for implementation details

  def initialize
    @tabs = []
  end

  def view_template(&)
    vanish(&)

    render_panel do
      render_nav do
        @tabs.each do |tab|
          render_nav_tab(tab[:name])
        end
      end

      render_contents do
        @tabs.each do |tab|
          render_content(tab[:name], &tab[:content])
        end
      end
    end
  end

  def tab(name, &content)
    @tabs << { name:, content: }
  end

  private

  def render_panel(&)
    div(
      class: "w-full",
      data: { controller: "tab", tab_default_value: @tabs.first[:name].parameterize },
      &)
  end

  def render_nav(&)
    nav(class: "flex border-b border-stone-500 mb-4 gap-2", &)
  end

  def render_nav_tab(name)
    button(
      type: "button",
      class: [
        "px-4 py-2 mt-2 font-semibold text-stone-200 cursor-pointer",
        "hover:bg-stone-800 hover:rounded-t-md",
        "data-[active]:bg-stone-700 data-[active]:rounded-t-md data-[active]:hover:bg-stone-700"
      ],
      data: {
        action: "click->tab#switch",
        tab_target: "button",
        tag: name.parameterize
      }
    ) { name }
  end

  def render_contents(&)
    div(class: "w-full", &)
  end

  def render_content(name, &)
    div(
      class: "w-full hidden",
      id: "tab-#{name.parameterize}",
      data: {
        tab_target: "content",
        tag: name.parameterize
      },
      &)
  end
end
