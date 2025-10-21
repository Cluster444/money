module Monetize
  extend ActiveSupport::Concern

  class_methods do
    def monetize(*attributes)
      attributes.each do |attr|
        # Override the getter to return dollars
        define_method(attr) do
          value = super()
          return nil if value.nil?
          value / 100.0
        end

        # Override the setter to convert dollars to cents
        define_method("#{attr}=") do |value|
          if value.present?
            super((BigDecimal(value.to_s) * 100).round)
          else
            super(nil)
          end
        end
      end
    end
  end
end
