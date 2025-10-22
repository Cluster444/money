class UpdateAccountKindsToStiFormat < ActiveRecord::Migration[8.0]
  def up
    # Update old kind values to new STI format
    Account.where(kind: "cash").update_all(kind: "Account::Cash")
    Account.where(kind: "vendor").update_all(kind: "Account::Vendor")
    Account.where(kind: "credit_card").update_all(kind: "Account::CreditCard")
    Account.where(kind: "customer").update_all(kind: "Account::Customer")
  end

  def down
    # Revert back to old format
    Account.where(kind: "Account::Cash").update_all(kind: "cash")
    Account.where(kind: "Account::Vendor").update_all(kind: "vendor")
    Account.where(kind: "Account::CreditCard").update_all(kind: "credit_card")
    Account.where(kind: "Account::Customer").update_all(kind: "customer")
  end
end
