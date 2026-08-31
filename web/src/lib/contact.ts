// お問い合わせ窓口の共通定義。法定ページ(特商法・プライバシー)で利用する。

/** サイト名。お問い合わせメールの件名プレフィックスに使う。 */
export const SITE_NAME = "クチコミ返信AI";

/** 運営者のお問い合わせメールアドレス。Vercel/.env の NEXT_PUBLIC_OPERATOR_EMAIL で設定。 */
export const OPERATOR_EMAIL =
  process.env.NEXT_PUBLIC_OPERATOR_EMAIL ?? "(未設定)";

/**
 * mailto リンクを生成する。メールソフト起動時に、件名へサイト名つきの
 * プレフィックス(例: 「クチコミ返信AIサービスについて」)が入った状態で
 * 新規メールが作成される。
 */
export function buildContactMailto(
  email: string = OPERATOR_EMAIL,
  subject: string = `${SITE_NAME}サービスについて`,
): string {
  return `mailto:${email}?subject=${encodeURIComponent(subject)}`;
}
