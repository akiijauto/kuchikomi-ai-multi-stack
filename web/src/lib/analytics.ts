// クライアント側の計測ヘルパー。
// GA4(gtag)とMeta Pixel(fbq)が読み込まれていれば送信し、未設定なら無処理(no-op)。
// 計測IDは NEXT_PUBLIC_GA_MEASUREMENT_ID / NEXT_PUBLIC_META_PIXEL_ID で設定する。

declare global {
  interface Window {
    gtag?: (...args: unknown[]) => void;
    fbq?: (...args: unknown[]) => void;
  }
}

// ビルド時にそのままスクリプトタグへ展開するため、想定外の形式は無視してXSSを防ぐ。
const GA_ID_RE = /^G-[A-Z0-9]{4,}$/;
const PIXEL_ID_RE = /^\d{10,20}$/;

export const GA_MEASUREMENT_ID = GA_ID_RE.test(
  process.env.NEXT_PUBLIC_GA_MEASUREMENT_ID ?? "",
)
  ? process.env.NEXT_PUBLIC_GA_MEASUREMENT_ID
  : undefined;

export const META_PIXEL_ID = PIXEL_ID_RE.test(
  process.env.NEXT_PUBLIC_META_PIXEL_ID ?? "",
)
  ? process.env.NEXT_PUBLIC_META_PIXEL_ID
  : undefined;

/**
 * 新規登録(初回のみ)。Confirm email=OFF のため、signUp 成功直後に1回だけ呼ぶ。
 * signup 処理の経路内で呼ぶので登録1回につき1発。ログイン経路では呼ばない。
 */
export function trackSignUp() {
  window.gtag?.("event", "sign_up", { method: "email" });
  window.fbq?.("track", "CompleteRegistration");
}

/**
 * 初回課金。Stripe の success_url 着地ページで、Checkout Session ID をキーに1回だけ撃つ。
 * リロードや別タブでの再訪による二重発火は localStorage で防ぐ。Pixel は eventID に sessionId を使い、
 * 将来 CAPI を足したときにサーバー側イベントと重複排除できるようにする。
 */
export function trackFirstPurchase(sessionId: string, value: number) {
  if (!sessionId) return;
  const key = `fp_tracked_${sessionId}`;
  try {
    if (localStorage.getItem(key)) return;
    localStorage.setItem(key, "1");
  } catch {
    // localStorage が使えない環境では重複排除を諦め、撃つことを優先する
  }
  window.gtag?.("event", "purchase", {
    transaction_id: sessionId,
    value,
    currency: "JPY",
  });
  window.fbq?.(
    "track",
    "Purchase",
    { value, currency: "JPY" },
    { eventID: sessionId },
  );
}
