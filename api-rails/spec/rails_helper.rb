ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
abort("本番環境ではテストを実行しない") if Rails.env.production?
require "rspec/rails"

RSpec.configure do |config|
  config.fixture_paths = [] if config.respond_to?(:fixture_paths=)
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  # スキーマは web/supabase/schema.sql が正本で、Railsのマイグレーションでは作らない。
  # そのため use_transactional_fixtures ではなく、毎回自分で消す。
  config.before(:each) do
    ActiveRecord::Base.connection.execute("truncate table public.usage_logs, public.profiles cascade")
    ActiveRecord::Base.connection.execute("delete from auth.users")
  end
end
Dir[Rails.root.join("spec/support/**/*.rb")].sort.each { |f| require f }
