import { NextResponse } from "next/server";
import { z } from "zod";
import { createClient } from "@/lib/supabase/server";
import { recommendNoteOptions } from "@/lib/note-draft/gemini";

const requestSchema = z.object({
  theme: z.string().min(2).max(200),
});

export async function POST(request: Request) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) {
    return NextResponse.json({ error: "ログインが必要です" }, { status: 401 });
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: "不正なリクエストです" }, { status: 400 });
  }

  const parsed = requestSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json(
      { error: "テーマを入力してください(2文字以上)" },
      { status: 400 },
    );
  }

  try {
    const result = await recommendNoteOptions(parsed.data.theme);
    return NextResponse.json(result);
  } catch (e) {
    console.error("note option recommendation failed:", e);
    return NextResponse.json(
      { error: "提案の生成に失敗しました。時間をおいて再度お試しください" },
      { status: 500 },
    );
  }
}
