import { type NextRequest } from "next/server";
import { updateSession } from "@/lib/supabase/middleware";

export async function proxy(request: NextRequest) {
  return updateSession(request);
}

export const config = {
  matcher: [
    // api/health は死活監視用。Supabaseへの問い合わせを挟むと
    // 認証基盤の障害がヘルスチェック失敗として現れてしまうため除外する。
    "/((?!_next/static|_next/image|favicon.ico|api/health|.*\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
};
