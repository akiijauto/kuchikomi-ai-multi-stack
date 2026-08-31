import { NextResponse } from "next/server";
import { z } from "zod";
import { createClient } from "@/lib/supabase/server";

const profileSchema = z.object({
  storeName: z.string().min(1).max(50),
  industry: z.string().min(1).max(30),
  tone: z.enum(["polite", "friendly", "casual"]),
  signature: z.string().max(30).optional(),
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

  const parsed = profileSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json(
      { error: "入力内容を確認してください" },
      { status: 400 },
    );
  }

  const { error } = await supabase
    .from("profiles")
    .update({
      store_name: parsed.data.storeName,
      industry: parsed.data.industry,
      tone: parsed.data.tone,
      signature: parsed.data.signature ?? "",
    })
    .eq("id", user.id);

  if (error) {
    return NextResponse.json(
      { error: "保存に失敗しました。時間をおいて再度お試しください" },
      { status: 500 },
    );
  }

  return NextResponse.json({ ok: true });
}
