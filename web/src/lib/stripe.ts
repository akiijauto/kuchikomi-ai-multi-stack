import Stripe from "stripe";

// 未設定時はビルドを通すためのダミー値(実行時にAPI呼び出しを行うと失敗する)
export const stripe = new Stripe(
  process.env.STRIPE_SECRET_KEY || "sk_test_dummy_key_for_build",
);
