require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "money_field helper exists" do
    # Test that the helper method exists and can be called
    assert_respond_to self, :money_field

    # Test basic functionality with a mock form object
    mock_form = Object.new
    mock_form.define_singleton_method(:object) { Adjustment.new(credit_amount: 10.50) }
    mock_form.define_singleton_method(:number_field) { |method, options| "number_field_#{method}" }

    result = money_field(mock_form, :credit_amount)
    assert_not_nil result
    assert_includes result, "number_field_credit_amount"
  end
end
