require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "cents_to_dollars converts cents to dollars correctly" do
    assert_equal 10.50, cents_to_dollars(1050)
    assert_equal 0.01, cents_to_dollars(1)
    assert_equal 100.00, cents_to_dollars(10000)
    assert_equal 0.0, cents_to_dollars(0)
    assert_nil cents_to_dollars(nil)
  end

  test "dollars_to_cents converts dollars to cents correctly" do
    assert_equal 1050, dollars_to_cents(10.50)
    assert_equal 1050, dollars_to_cents("10.50")
    assert_equal 1, dollars_to_cents(0.01)
    assert_equal 10000, dollars_to_cents(100.00)
    assert_equal 0, dollars_to_cents(0)
    assert_nil dollars_to_cents(nil)
  end

  test "dollars_to_cents handles rounding correctly" do
    assert_equal 101, dollars_to_cents(1.005)  # Should round up
    assert_equal 100, dollars_to_cents(1.004)  # Should round down
    assert_equal 99, dollars_to_cents(0.994)   # Should round down
    assert_equal 99, dollars_to_cents(0.985)   # Should round up
  end

  test "money_field helper exists" do
    # Test that the helper method exists and can be called
    assert_respond_to self, :money_field

    # Test basic functionality with a mock form object
    mock_form = Object.new
    mock_form.define_singleton_method(:object) { Adjustment.new(credit_amount: 1050) }
    mock_form.define_singleton_method(:number_field) { |method, options| "number_field_#{method}" }

    result = money_field(mock_form, :credit_amount)
    assert_not_nil result
    assert_includes result, "number_field_credit_amount"
  end
end
