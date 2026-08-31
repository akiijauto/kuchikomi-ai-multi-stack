import { NextResponse } from "next/server";

// コンテナ/ロードバランサ用の死活監視エンドポイント。
// 認証基盤(Supabase)に依存させないため、proxy.ts の matcher から除外している。
// ここが落ちる＝プロセス自体が応答していない、と切り分けられる状態を保つ。
export const dynamic = "force-dynamic";

export function GET() {
  return NextResponse.json({ status: "ok", uptime: process.uptime() });
}
