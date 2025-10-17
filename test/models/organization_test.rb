require "test_helper"

class OrganizationTest < ActiveSupport::TestCase
  test "should destroy associated accounts when organization is destroyed" do
    organization = organizations(:lazaro_personal)
    original_account_count = organization.accounts.count

    # Verify the organization has accounts
    assert original_account_count > 0, "Organization should have accounts to test cascade deletion"

    # Get the account IDs before destruction
    account_ids = organization.accounts.pluck(:id)

    # Destroy the organization
    assert_difference "Account.count", -original_account_count do
      organization.destroy
    end

    # Verify all associated accounts are destroyed
    account_ids.each do |account_id|
      assert_not Account.exists?(account_id), "Account #{account_id} should be destroyed when organization is destroyed"
    end
  end
end
