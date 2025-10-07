require "test_helper"

class SessionTest < ActiveSupport::TestCase
  setup do
    @user = users(:lazaro_nixon)
  end

  test "should belong to user" do
    session = Session.new(ip_address: "127.0.0.1", user_agent: "Test Browser")
    assert_not session.valid?
    assert_includes session.errors[:user], "must exist"

    session.user = @user
    assert session.valid?
  end

  test "should store ip_address" do
    session = @user.sessions.create!(ip_address: "192.168.1.1", user_agent: "Test Browser")
    assert_equal "192.168.1.1", session.ip_address
  end

  test "should store user_agent" do
    session = @user.sessions.create!(ip_address: "127.0.0.1", user_agent: "Mozilla/5.0 Test Browser")
    assert_equal "Mozilla/5.0 Test Browser", session.user_agent
  end
end
