require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get new_user_path
    assert_response :success
  end

  test "should create user and sign in immediately" do
    assert_difference("User.count") do
      post users_path, params: { user: {
        first_name: "John",
        last_name: "Doe",
        email_address: "john@example.com",
        password: "password123",
        password_confirmation: "password123"
      } }
    end

    assert_redirected_to accounts_path
    assert_equal "Welcome! Your account has been created successfully.", flash[:notice]
  end

  test "should not create user with invalid data" do
    assert_no_difference("User.count") do
      post users_path, params: { user: {
        first_name: "",
        last_name: "Doe",
        email_address: "invalid-email",
        password: "123",
        password_confirmation: "456"
      } }
    end

    assert_response :unprocessable_entity
  end

  test "should not create user with duplicate email" do
    existing_user = users(:lazaro_nixon)

    assert_no_difference("User.count") do
      post users_path, params: { user: {
        first_name: "Jane",
        last_name: "Smith",
        email_address: existing_user.email_address,
        password: "password123",
        password_confirmation: "password123"
      } }
    end

    assert_response :unprocessable_entity
  end
end
