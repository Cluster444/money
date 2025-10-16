require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    @user = users(:lazaro_nixon)
  end

  test "should be valid with required attributes" do
    assert @user.valid?
  end

  test "should require first_name" do
    @user.first_name = nil
    assert_not @user.valid?
    assert_includes @user.errors[:first_name], "can't be blank"
  end

  test "should require last_name" do
    @user.last_name = nil
    assert_not @user.valid?
    assert_includes @user.errors[:last_name], "can't be blank"
  end

  test "should require email_address" do
    @user.email_address = nil
    assert_not @user.valid?
    assert_includes @user.errors[:email_address], "can't be blank"
  end

  test "should require password_digest" do
    @user.password_digest = nil
    assert_not @user.valid?
    assert_includes @user.errors[:password], "can't be blank"
  end

  test "should normalize email address" do
    @user.email_address = "  TEST@EXAMPLE.COM  "
    @user.valid?
    assert_equal "test@example.com", @user.email_address
  end

  test "should require unique email address" do
    duplicate_user = User.new(
      first_name: "Jane",
      last_name: "Doe",
      email_address: @user.email_address,
      password: "password123"
    )
    assert_not duplicate_user.valid?
    assert_includes duplicate_user.errors[:email_address], "has already been taken"
  end

  test "should authenticate with valid password" do
    authenticated_user = User.authenticate_by(email_address: @user.email_address, password: "password123")
    assert_equal @user, authenticated_user
  end

  test "should not authenticate with invalid password" do
    authenticated_user = User.authenticate_by(email_address: @user.email_address, password: "wrongpassword")
    assert_nil authenticated_user
  end

  test "should require password confirmation" do
    user = User.new(
      first_name: "Test",
      last_name: "User",
      email_address: "test@example.com",
      password: "password123",
      password_confirmation: "different"
    )
    assert_not user.valid?
    assert_includes user.errors[:password_confirmation], "doesn't match Password"
  end

  test "should have many sessions" do
    assert_difference "@user.sessions.count", 2 do
      @user.sessions.create!(ip_address: "127.0.0.1", user_agent: "Test Browser")
      @user.sessions.create!(ip_address: "192.168.1.1", user_agent: "Another Browser")
    end
  end

  test "should destroy sessions when user destroyed" do
    session = @user.sessions.create!(ip_address: "127.0.0.1", user_agent: "Test Browser")
    assert_difference "Session.count", -2 do  # User already has 1 session in fixtures, creating 1 more = 2 total
      # Clean up organizations and accounts first to avoid foreign key constraints
      @user.organizations.each { |org| org.accounts.destroy_all }
      @user.organizations.destroy_all
      @user.destroy
    end
    assert_raises(ActiveRecord::RecordNotFound) { session.reload }
  end

  test "should create personal organization after user creation" do
    assert_difference "Organization.count", 1 do
      User.create!(
        first_name: "John",
        last_name: "Doe",
        email_address: "john.doe@example.com",
        password: "password123"
      )
    end

    user = User.find_by(email_address: "john.doe@example.com")
    assert_equal 1, user.organizations.count
    assert_equal "Personal", user.organizations.first.name
  end
end
