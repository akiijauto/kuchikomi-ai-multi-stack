import { NextResponse } from "next/server";
import { stripe } from "@/lib/stripe";
import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";

export async function POST(request: Request) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) {
    return NextResponse.json({ error: "ログインが必要です" }, { status: 401 });
  }

  const priceId = process.env.STRIPE_PRICE_ID_PRO;
  if (!priceId) {
    return NextResponse.json(
      { error: "決済が設定されていません" },
      { status: 500 },
    );
  }

  const { data: profile } = await supabase
    .from("profiles")
    .select("stripe_customer_id")
    .eq("id", user.id)
    .single();

  const origin = new URL(request.url).origin;

  let customerId = profile?.stripe_customer_id ?? undefined;
  if (!customerId) {
    const customer = await stripe.customers.create({
      email: user.email,
      metadata: { supabase_user_id: user.id },
    });
    customerId = customer.id;
    // stripe_customer_id は利用者に更新権限を与えていない列のため、
    // サーバー管理の情報として管理者クライアントで書き込む
    const { error: saveError } = await createAdminClient()
      .from("profiles")
      .update({ stripe_customer_id: customerId })
      .eq("id", user.id);
    if (saveError) {
      // 保存に失敗したまま進めると、次回checkoutでStripe顧客が重複作成される
      console.error("failed to persist stripe_customer_id:", saveError);
      return NextResponse.json(
        { error: "決済の準備に失敗しました。時間をおいて再度お試しください" },
        { status: 500 },
      );
    }
  }

  const session = await stripe.checkout.sessions.create({
    mode: "subscription",
    customer: customerId,
    client_reference_id: user.id,
    line_items: [{ price: priceId, quantity: 1 }],
    // session_id は first_purchase 計測の重複排除キー。Stripeが実IDに置換する。
    success_url: `${origin}/profile?checkout=success&session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${origin}/profile?checkout=cancel`,
  });

  return NextResponse.json({ url: session.url });
}
