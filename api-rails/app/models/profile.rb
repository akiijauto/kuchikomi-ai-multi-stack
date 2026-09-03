# web/supabase/schema.sql の public.profiles に対応する。
# Railsのマイグレーションでは作らない（正本はSQL側）。
class Profile < ApplicationRecord
  self.primary_key = "id"

  TONES = %w[polite friendly casual].freeze
  PLANS = %w[free pro].freeze
end
