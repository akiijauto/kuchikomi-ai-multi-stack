module Api
  # 死活監視。Next.js版の /api/health と同じく、認証基盤やDBに依存させない。
  # ここがDBを見に行くと「アプリは生きているがDBが不調」でコンテナごと
  # 落とされることになり、切り分けができなくなる。
  class HealthController < ApplicationController
    def show
      render json: { status: "ok", uptime: Process.clock_gettime(Process::CLOCK_MONOTONIC) - BOOTED_AT }
    end

    BOOTED_AT = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
