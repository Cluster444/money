require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:lazaro_nixon)
  end

  test "should get new password reset form" do
    get new_password_url
    assert_response :success
  end

  test "should send reset email for existing user" do
    assert_enqueued_email_with PasswordsMailer, :reset, args: [ @user ] do
      post passwords_url, params: { email_address: @user.email_address }
    end
    assert_redirected_to new_session_url
    assert_equal "You will receive an email with instructions on how to reset your password in a few minutes.", flash[:notice]
  end

  test "should not error for nonexistent user" do
    assert_no_enqueued_emails do
      post passwords_url, params: { email_address: "nonexistent@example.com" }
    end
    assert_redirected_to new_session_url
    assert_equal "You will receive an email with instructions on how to reset your password in a few minutes.", flash[:notice]
  end

  test "should redirect to login after reset request" do
    post passwords_url, params: { email_address: @user.email_address }
    assert_redirected_to new_session_url
  end

  test "should get edit with valid token" do
    token = @user.password_reset_token
    get edit_password_url(token)
    assert_response :success
  end

  test "should not get edit with invalid token" do
    get edit_password_url("invalid_token")
    assert_redirected_to new_password_url
    assert_equal "Your password reset link has expired. Please try again.", flash[:alert]
  end

  test "should update password with matching passwords" do
    token = @user.password_reset_token
    patch password_url(token), params: { password: "newpassword123", password_confirmation: "newpassword123" }
    assert_redirected_to new_session_url
    assert_equal "Your password has been reset. Please sign in.", flash[:notice]

    # Verify new password works
    post session_url, params: { email_address: @user.email_address, password: "newpassword123" }
    assert_redirected_to root_url
  end

  test "should not update password with mismatched passwords" do
    token = @user.password_reset_token
    patch password_url(token), params: { password: "newpassword123", password_confirmation: "different" }
    assert_response :unprocessable_entity
    assert_select "div", /Password confirmation doesn't match Password/
  end

  test "should not update with invalid token" do
    patch password_url("invalid_token"), params: { password: "newpassword123", password_confirmation: "newpassword123" }
    assert_redirected_to new_password_url
    assert_equal "Your password reset link has expired. Please try again.", flash[:alert]
  end

  test "should redirect with notice on success" do
    token = @user.password_reset_token
    patch password_url(token), params: { password: "newpassword123", password_confirmation: "newpassword123" }
    assert_redirected_to new_session_url
    assert_equal "Your password has been reset. Please sign in.", flash[:notice]
  end

  test "should redirect with alert on failure" do
    token = @user.password_reset_token
    patch password_url(token), params: { password: "newpassword123", password_confirmation: "different" }
    assert_response :unprocessable_entity
  end
end
