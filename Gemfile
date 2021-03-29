source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Specify your gem's dependencies in shop_invader.gemspec
gemspec

gem 'locomotivecms_steam', github: 'akretion/steam', branch: 'rebase-better-attribute-parser'
gem 'faraday'
gem 'algoliasearch'
gem 'elasticsearch'

group :test do
  gem 'simplecov',      require: false
  gem 'codecov',        require: false
  gem 'byebug',         require: false
  gem 'rack-test'
  gem 'haml'
  gem 'pg'
  gem 'rake'
  gem 'rspec'
  gem 'rack-utm'
end
