# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Truncate all tables first
ActiveRecord::Base.connection.tables.each do |table|
  next if table == "schema_migrations" # Skip the migrations table
  ActiveRecord::Base.connection.execute("DELETE FROM #{table}")
  ActiveRecord::Base.connection.execute("DELETE FROM sqlite_sequence WHERE name='#{table}'") if ActiveRecord::Base.connection.adapter_name.downcase == 'sqlite'
end

# Create test user
User.create!(
  email_address: "user@local.dev",
  password: "password",
  password_confirmation: "password",
  first_name: "Test",
  last_name: "User"
)
