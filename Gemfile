# frozen_string_literal: true

source "https://rubygems.org"

# One source of truth for the Ruby version: .ruby-version (the Dockerfile's
# RUBY_VERSION ARG and CI's ruby-version-file read the same file).
ruby file: ".ruby-version"

gem "dry-monads", "~> 1.8", require: "dry/monads" # Success/Failure Results
gem "erubi", "~> 1.13" # makes `set :erb, escape_html: true` real (ERB auto-escaping)
gem "faraday", "~> 2.13" # HTTP client for service wrappers
gem "puma", "~> 6.6" # app server (config/puma.rb)
gem "rackup", "~> 2.2" # `run App` entrypoint (config.ru)
gem "rake", "~> 13.2" # `rake db:migrate` (the deploy gate)
gem "sequel", "~> 5.90" # ORM + migrations
gem "sinatra", "~> 4.1", require: "sinatra/base" # modular app, no classic DSL
gem "sqlite3", "~> 2.6" # the only DB backend

group :development, :test do
  gem "csv", "~> 3.3" # seed-tuning specs read db/seed-data/*.csv; not a default gem from Ruby 3.4
  gem "dotenv", "~> 3.1"
  gem "factory_bot", "~> 6.5"
  gem "rack-test", "~> 2.2", require: "rack/test"
  gem "rspec", "~> 3.13"
  gem "rubocop", "~> 1.75", require: false
  gem "rubocop-rspec", "~> 3.5", require: false
  gem "rubocop-sequel", "~> 0.3", require: false
end

group :test do
  gem "capybara", "~> 3.40"
end
