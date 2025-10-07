require "test_helper"

class AuthenticationFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:lazaro_nixon)
  end

  test "full login logout flow" do
    # Start at login page
    get new_session_url
    assert_response :success

    # Login with valid credentials
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    assert_redirected_to root_url
    follow_redirect!
    assert_response :success

    # Verify we're authenticated by checking session cookie exists
    assert_not_nil cookies[:session_id]

    # Logout
    delete session_url
    assert_redirected_to new_session_url
    follow_redirect!

    # Verify we're logged out by checking session cookie is deleted
    assert_empty cookies[:session_id]
    get root_url
    assert_redirected_to new_session_url
  end

  test "session persistence across requests" do
    # Login
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    assert_redirected_to root_url

    # Make multiple requests
    3.times do
      get root_url
      assert_response :success
      # Verify session persists by checking we're not redirected to login
      assert_not_equal new_session_url, response.location
    end
  end

  test "password reset complete flow" do
    # Request password reset
    assert_enqueued_email_with PasswordsMailer, :reset, args: [ @user ] do
      post passwords_url, params: { email_address: @user.email_address }
    end
    assert_redirected_to new_session_url

    # Get reset token from user (in real app this would come from email)
    token = @user.password_reset_token

    # Visit reset form
    get edit_password_url(token)
    assert_response :success

    # Update password
    patch password_url(token), params: {
      password: "newpassword123",
      password_confirmation: "newpassword123"
    }
    assert_redirected_to new_session_url

    # Login with new password
    post session_url, params: { email_address: @user.email_address, password: "newpassword123" }
    assert_redirected_to root_url
  end
end
