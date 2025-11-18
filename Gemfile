source "https://rubygems.org"

gem "rails", "8.1.1"
gem "propshaft", "1.3.1"
gem "sqlite3", "2.7.4"
gem "puma", "7.1.0"
gem "importmap-rails", "2.2.2"
gem "turbo-rails", "2.0.17"
gem "stimulus-rails", "1.3.4"
gem "phlex-rails", "2.3.1"
gem "tailwindcss-rails", "4.3.0"
gem "tailwindcss-ruby", "4.1.13"
gem "jbuilder", "2.14.1"
gem "bcrypt", "3.1.20"

gem "solid_cache", "1.0.8"
gem "solid_queue", "1.2.2"
gem "solid_cable", "3.0.12"

gem "bootsnap", require: false
gem "kamal", require: false
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"
#
gem "tzinfo-data", platforms: %i[ windows jruby ]

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "web-console"
  gem "localhost"
  gem "hotwire-spark"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  # gem "capybara"
  # gem "selenium-webdriver"
end
