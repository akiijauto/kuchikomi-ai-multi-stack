# Supabaseが発行するトークンと同じ形のものをテスト用に作る。
# 本物のSupabaseは要らない。署名鍵が一致していれば検証は通る。
module AuthHelper
  TEST_JWT_SECRET = "test-secret-for-rspec-only-not-a-real-key"

  def auth_header(user_id, secret: TEST_JWT_SECRET, exp: Time.now.to_i + 3600)
    token = JWT.encode({ sub: user_id, aud: "authenticated", exp: exp }, secret, "HS256")
    { "Authorization" => "Bearer #{token}" }
  end

  def create_user_with_profile(plan: "free", store_name: "テスト店", tone: "polite", signature: "")
    id = SecureRandom.uuid
    ActiveRecord::Base.connection.execute(
      "insert into auth.users (id, email) values ('#{id}', '#{id}@example.test')"
    )
    Profile.create!(
      id: id, store_name: store_name, industry: "飲食店",
      tone: tone, signature: signature, plan: plan
    )
    id
  end
end

RSpec.configure do |config|
  config.include AuthHelper
  config.before(:suite) { ENV["SUPABASE_JWT_SECRET"] = AuthHelper::TEST_JWT_SECRET }
end
