import { NextResponse } from "next/server";
import { z } from "zod";
import { generateReviewReplies } from "@/lib/generation/engine";
import { createClient } from "@/lib/supabase/server";
import { PLAN_LIMITS, currentMonthKey, type Plan } from "@/lib/plans";
import type { StoreProfile } from "@/lib/generation/types";

const requestSchema = z.object({
  review: z.object({
    reviewText: z.string().min(5).max(2000),
    rating: z.union([
      z.literal(1),
      z.literal(2),
      z.literal(3),
      z.literal(4),
      z.literal(5),
    ]),
  }),
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

  const { data: profileRow } = await supabase
    .from("profiles")
    .select("store_name, industry, tone, signature, plan")
    .eq("id", user.id)
    .single();

  if (!profileRow || !profileRow.store_name) {
    return NextResponse.json(
      { error: "先にお店のプロフィールを設定してください" },
      { status: 400 },
    );
  }

  const plan = profileRow.plan as Plan;
  const month = currentMonthKey();
  // エラー文言・レスポンス表示用。上限の強制はDB側(plan_limitsテーブル)が正本
  const limit = PLAN_LIMITS[plan];

  // 上限チェックと加算はDB関数内で原子的に行う(同時リクエストでも上限を超えない)。
  // 上限値は渡さない: DB関数が呼び出した本人の profiles.plan から決める(偽装防止)
  const { data: newCount, error: usageError } = await supabase.rpc(
    "increment_usage",
    { p_month: month },
  );
  if (usageError) {
    // P0001 = increment_usage が上限超過時に投げる例外のSQLSTATE
    if (usageError.code === "P0001") {
      return NextResponse.json(
        {
          error:
            plan === "free"
              ? `今月の無料利用回数(${limit}件)の上限に達しました。プロプランへのアップグレードをご検討ください`
              : `今月の利用回数(${limit}件)の上限に達しました`,
        },
        { status: 429 },
      );
    }
    console.error("usage increment failed:", usageError);
    return NextResponse.json(
      { error: "生成に失敗しました。時間をおいて再度お試しください" },
      { status: 500 },
    );
  }

  const profile: StoreProfile = {
    storeName: profileRow.store_name,
    industry: profileRow.industry,
    tone: profileRow.tone as StoreProfile["tone"],
    signature: profileRow.signature || undefined,
  };

  try {
    const result = await generateReviewReplies(profile, parsed.data.review);
    return NextResponse.json({
      ...result,
      usage: { used: newCount as number, limit },
    });
  } catch (e) {
    console.error("generation failed:", e);
    return NextResponse.json(
      { error: "生成に失敗しました。時間をおいて再度お試しください" },
      { status: 500 },
    );
  }
}
