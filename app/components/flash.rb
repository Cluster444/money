# frozen_string_literal: true

class Components::Flash < Components::Base
  def initialize(messages:)
    @messages = messages
  end

  def view_template
    return unless flash_messages.any?

    div(class: "absolute top-12 left-0 right-0 z-50 max-w-80 mx-auto px-2") do
      div(class: "space-y-2") do
        flash_messages.each do |type, message|
          case type
          when :alert
            div(
              class: "h-12 bg-red-900 text-red-100 border border-red-700 px-4 rounded-lg flex items-center justify-between cursor-pointer",
              data: { controller: "flash", timeout: 5000, action: "click->flash#dismiss" }
            ) do
              div(class: "flex-1 text-left") { message }
              div(
                class: "ml-4 text-red-200 font-mono text-sm",
                data: { flash_target: "countdown" }
              )
            end
          when :notice
            div(
              class: "h-12 bg-green-900 text-green-100 border border-green-700 px-4 rounded-lg flex items-center justify-between cursor-pointer",
              data: { controller: "flash", timeout: 5000, action: "click->flash#dismiss" }
            ) do
              div(class: "flex-1 text-left") { message }
              div(
                class: "ml-4 text-green-200 font-mono text-sm",
                data: { flash_target: "countdown" }
              )
            end
          end
        end
      end
    end
  end

  private

  attr_reader :messages

  def flash_messages
    messages.slice(:alert, :notice)
  end
end
