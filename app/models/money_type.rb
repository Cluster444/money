# Custom Rails attribute type for handling money values
# Stores money as cents in the database, but works with dollars in the application
class MoneyType < ActiveModel::Type::Integer
  def cast(value)
    case value
    when nil
      nil
    when String
      # Convert dollar string to cents
      value.blank? ? nil : (BigDecimal(value) * 100).round
    when Numeric
      # Assume it's already in cents if it's an integer, convert if float
      value.is_a?(Integer) ? value : (BigDecimal(value.to_s) * 100).round
    else
      super
    end
  end

  def serialize(value)
    case value
    when nil
      nil
    when String
      value.blank? ? nil : (BigDecimal(value) * 100).round
    when Numeric
      # Always store as integer cents
      value.is_a?(Integer) ? value : (BigDecimal(value.to_s) * 100).round
    else
      super
    end
  end

  def deserialize(value)
    value
  end
end
