export type Plan = "free" | "pro";

// 生成回数上限の正本はDB側(web/supabase/schema.sql の plan_limits テーブル)で、
// 上限の強制もDB側で行う。ここは画面表示・エラー文言用の複製。
// 上限を変更するときは必ず両方を同じ値に更新すること。
export const PLAN_LIMITS: Record<Plan, number> = {
  free: 5,
  pro: 300,
};

export const PLAN_LABELS: Record<Plan, string> = {
  free: "無料プラン",
  pro: "プロプラン",
};

// 月額料金(円)。Stripeの価格(STRIPE_PRICE_ID_PRO)と必ず同じ値にすること。
export const PLAN_PRICES: Record<Plan, number> = {
  free: 0,
  pro: 980,
};

/** 利用回数の集計単位(YYYY-MM、UTC基準) */
export function currentMonthKey(date = new Date()): string {
  const year = date.getUTCFullYear();
  const month = String(date.getUTCMonth() + 1).padStart(2, "0");
  return `${year}-${month}`;
}
