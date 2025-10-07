require "test_helper"

class SessionsController::AuthenticationTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:lazaro_nixon)
  end

  test "should allow unauthenticated access to login" do
    get new_session_url
    assert_response :success

    post session_url, params: { email_address: @user.email_address, password: "password123" }
    assert_redirected_to root_url
  end

  test "should require authentication for protected actions" do
    # Test a protected controller that requires authentication
    get root_url
    assert_redirected_to new_session_url
  end

  test "should resume session from cookie" do
    # Login and get session cookie
    post session_url, params: { email_address: @user.email_address, password: "password123" }

    # Make another request with the cookie
    get root_url
    assert_response :success
  end

  test "should set current session and user" do
    post session_url, params: { email_address: @user.email_address, password: "password123" }

    # Verify session cookie was set
    assert_not_nil cookies[:session_id]

    get root_url

    # Verify we're authenticated (not redirected to login)
    assert_response :success
  end

  test "should redirect authenticated users away from login" do
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    follow_redirect! # Follow the redirect to root_url first
    get new_session_url
    assert_redirected_to root_url
  end

  test "should clear current session on logout" do
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    get root_url

    # Verify we're authenticated
    assert_response :success

    delete session_url
    follow_redirect!

    # Verify we're no longer authenticated
    get root_url
    assert_redirected_to new_session_url
  end
end
