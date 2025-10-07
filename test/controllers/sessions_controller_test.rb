require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:lazaro_nixon)
  end

  test "should get new when unauthenticated" do
    get new_session_url
    assert_response :success
  end

  test "should redirect new when authenticated" do
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    get new_session_url
    assert_redirected_to root_url
  end

  test "should create session with valid credentials" do
    assert_difference "Session.count" do
      post session_url, params: { email_address: @user.email_address, password: "password123" }
    end
    assert_redirected_to root_url
    assert_not_nil cookies[:session_id]
  end

  test "should not create session with invalid credentials" do
    assert_no_difference "Session.count" do
      post session_url, params: { email_address: @user.email_address, password: "wrongpassword" }
    end
    assert_redirected_to new_session_url
  end

  test "should redirect after successful login" do
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    assert_redirected_to root_url
  end

  test "should rate limit login attempts" do
    10.times do
      post session_url, params: { email_address: @user.email_address, password: "wrongpassword" }
    end

    post session_url, params: { email_address: @user.email_address, password: "wrongpassword" }
    assert_redirected_to new_session_url
  end

  test "should show error with invalid credentials" do
    post session_url, params: { email_address: @user.email_address, password: "wrongpassword" }
    assert_redirected_to new_session_url
    assert_equal "Try another email address or password.", flash[:alert]
  end

  test "should destroy session and redirect" do
    post session_url, params: { email_address: @user.email_address, password: "password123" }

    assert_difference "Session.count", -1 do
      delete session_url
    end
    assert_empty cookies[:session_id]
  end

  test "should redirect to login after logout" do
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    delete session_url
    assert_redirected_to new_session_url
  end
end
