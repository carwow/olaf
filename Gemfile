# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

group :test, :development do
  # The client libraries of the drivers, which the gem does not depend on.
  # ruby-odbc is left out: no test opens a connection, and it needs the ODBC
  # system library to build.
  gem "google-cloud-bigquery", "~> 1.64"
  gem "sequel", "~> 5.37"
  gem "rake", "~> 13.0"
  gem "test-unit", "~> 3.3"
end
