import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { suggestTheme } from "@/lib/note-draft/suggest-theme";

export async function POST(request: Request) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) {
    return NextResponse.json({ error: "ログインが必要です" }, { status: 401 });
  }

  try {
    const result = await suggestTheme();
    return NextResponse.json(result);
  } catch (e) {
    console.error("theme suggestion failed:", e);
    return NextResponse.json(
      { error: "テーマの提案に失敗しました。時間をおいて再度お試しください" },
      { status: 500 },
    );
  }
}
