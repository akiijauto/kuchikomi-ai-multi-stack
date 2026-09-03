Rails.application.routes.draw do
  # Next.js版と同じURLに合わせる（/api/generate, /api/profile, /api/health）
  scope "/api" do
    get  "health",   to: "api/health#show"
    post "generate", to: "api/generate#create"
    post "profile",  to: "api/profiles#create"
  end
end
