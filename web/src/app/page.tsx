import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import {
  PLAN_LABELS,
  PLAN_LIMITS,
  PLAN_PRICES,
  currentMonthKey,
  type Plan,
} from "@/lib/plans";
import { Header } from "./header";
import { GenerateForm } from "./generate-form";
import { LinkPending } from "./link-pending";

export default async function Home() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) {
    return <LandingPage />;
  }

  const { data: profile } = await supabase
    .from("profiles")
    .select("store_name, plan")
    .eq("id", user.id)
    .single();

  const storeName = profile?.store_name ?? "";
  const plan = (profile?.plan ?? "free") as Plan;
  const limit = PLAN_LIMITS[plan];

  const { data: usageRow } = await supabase
    .from("usage_logs")
    .select("count")
    .eq("user_id", user.id)
    .eq("month", currentMonthKey())
    .maybeSingle();
  const used = usageRow?.count ?? 0;

  return (
    <main className="mx-auto w-full max-w-xl px-4 py-8">
      <Header storeName={storeName} userEmail={user.email} />

      <header className="mb-8 text-center">
        <h1 className="text-2xl font-bold">クチコミ返信AI</h1>
        <p className="mt-2 text-sm text-gray-500">
          口コミを貼り付けるだけ。お店らしい返信文が10秒で3案できあがります。
        </p>
      </header>

      {!storeName ? (
        <section className="rounded-xl border border-amber-200 bg-amber-50 p-4 text-center text-sm text-amber-800">
          <p className="mb-3">
            返信文を作成する前に、お店のプロフィールを設定してください。
          </p>
          <Link
            href="/profile"
            className="inline-block rounded-lg bg-amber-600 px-4 py-2 font-semibold text-white"
          >
            プロフィールを設定する
            <LinkPending />
          </Link>
        </section>
      ) : (
        <GenerateForm initialUsed={used} limit={limit} />
      )}

      <footer className="mt-12 text-center text-xs text-gray-400">
        クチコミ返信AI(β版)
      </footer>
    </main>
  );
}

function LandingPage() {
  return (
    <main className="mx-auto w-full max-w-xl px-4 py-12">
      <section className="text-center">
        <h1 className="text-3xl font-bold">クチコミ返信AI</h1>
        <p className="mt-4 text-base text-gray-600">
          AIが返信、あなたはワンクリック。プロンプトを毎回考える手間から解放されます。
        </p>
        <p className="mt-2 text-sm text-gray-500">
          美容室・サロン・飲食店のオーナー様向け。お店のプロフィールを一度登録すれば、口コミを貼るだけで「その店らしい」返信文が3案できあがります。
        </p>
        <div className="mt-8 flex flex-col gap-3 sm:flex-row sm:justify-center">
          <Link
            href="/login"
            className="rounded-xl bg-blue-600 px-6 py-3 font-semibold text-white"
          >
            無料で始める
            <LinkPending />
          </Link>
          <Link
            href="/login"
            className="rounded-xl border border-gray-300 px-6 py-3 font-semibold text-gray-700"
          >
            ログイン
            <LinkPending />
          </Link>
        </div>
        <p className="mt-3 text-xs text-gray-400">
          クレジットカード不要・メールアドレスだけで登録。無料プランで月
          {PLAN_LIMITS.free}件までお試しいただけます。
        </p>
      </section>

      <section className="mt-16 grid gap-6">
        <div className="rounded-xl border border-gray-200 p-5">
          <h2 className="font-semibold">口コミを貼るだけ</h2>
          <p className="mt-1 text-sm text-gray-500">
            お客様からの口コミ本文と評価を入力するだけで、AIがすぐに返信文の候補を作成します。
          </p>
        </div>
        <div className="rounded-xl border border-gray-200 p-5">
          <h2 className="font-semibold">お店らしいトーンで3案</h2>
          <p className="mt-1 text-sm text-gray-500">
            業種や文体(丁寧・フレンドリーなど)をプロフィールに設定すると、お店の雰囲気に合った返信文を複数提案します。
          </p>
        </div>
        <div className="rounded-xl border border-gray-200 p-5">
          <h2 className="font-semibold">そのままコピーして使える</h2>
          <p className="mt-1 text-sm text-gray-500">
            気に入った文章をワンタップでコピーし、各レビューサイトの管理画面に貼り付けるだけで返信が完了します。
          </p>
        </div>
      </section>

      <section className="mt-16">
        <h2 className="text-center text-xl font-bold">料金プラン</h2>
        <div className="mt-6 grid gap-4 sm:grid-cols-2">
          <div className="rounded-xl border border-gray-200 p-5 text-center">
            <h3 className="font-semibold">{PLAN_LABELS.free}</h3>
            <p className="mt-2 text-2xl font-bold">無料</p>
            <p className="mt-2 text-sm text-gray-500">
              月{PLAN_LIMITS.free}回まで返信文を生成できます
            </p>
          </div>
          <div className="rounded-xl border-2 border-blue-600 p-5 text-center">
            <h3 className="font-semibold">{PLAN_LABELS.pro}</h3>
            <p className="mt-2 text-2xl font-bold">
              {PLAN_PRICES.pro}円<span className="text-sm font-normal">/月</span>
            </p>
            <p className="mt-2 text-sm text-gray-500">
              月{PLAN_LIMITS.pro}回まで返信文を生成できます。小規模店舗の
              口コミ件数なら、まず使い切らない余裕の上限です。
            </p>
          </div>
        </div>
        <p className="mt-4 text-center">
          <Link href="/login" className="text-sm text-blue-600">
            無料プランで今すぐ試してみる →
            <LinkPending />
          </Link>
        </p>
      </section>
    </main>
  );
}
