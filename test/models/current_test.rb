require "test_helper"

class CurrentTest < ActiveSupport::TestCase
  setup do
    @user = users(:lazaro_nixon)
    @session = @user.sessions.create!(ip_address: "127.0.0.1", user_agent: "Test Browser")
  end

  test "should manage session attribute" do
    Current.session = @session
    assert_equal @session, Current.session

    Current.session = nil
    assert_nil Current.session
  end

  test "should delegate user to session" do
    Current.session = @session
    assert_equal @user, Current.user
  end

  test "should handle nil session" do
    Current.session = nil
    assert_nil Current.user
  end

  teardown do
    Current.reset
  end
end
