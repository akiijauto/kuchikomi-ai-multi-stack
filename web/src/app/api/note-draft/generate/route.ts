import { NextResponse } from "next/server";
import { z } from "zod";
import { createClient } from "@/lib/supabase/server";
import { generateNoteDraft } from "@/lib/note-draft/engine";

const requestSchema = z.object({
  theme: z.string().min(2).max(200),
  angle: z.string().min(2).max(500),
  targetReader: z.string().min(2).max(200),
  tone: z.enum(["polite", "friendly", "casual"]),
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
      { error: "入力内容を確認してください" },
      { status: 400 },
    );
  }

  try {
    const result = await generateNoteDraft(parsed.data);
    return NextResponse.json(result);
  } catch (e) {
    console.error("note draft generation failed:", e);
    return NextResponse.json(
      { error: "生成に失敗しました。時間をおいて再度お試しください" },
      { status: 500 },
    );
  }
}
