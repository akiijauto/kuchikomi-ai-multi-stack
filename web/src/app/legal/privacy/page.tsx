import { OPERATOR_EMAIL, buildContactMailto } from "@/lib/contact";

export const metadata = {
  title: "プライバシーポリシー | クチコミ返信AI",
};

export default function PrivacyPage() {
  return (
    <>
      <h1 className="mb-6 text-xl font-bold">プライバシーポリシー</h1>

      <p>
        クチコミ返信AI(以下「本サービス」といいます)は、お客様の個人情報を
        以下のとおり取り扱います。
      </p>

      <h2 className="mt-6 mb-2 font-bold">1. 取得する情報</h2>
      <p>本サービスは、以下の情報を取得することがあります。</p>
      <ul className="ml-5 list-disc">
        <li>メールアドレス(アカウント登録時)</li>
        <li>店舗名・業種・口調設定・署名などのプロフィール情報</li>
        <li>入力されたクチコミ本文および生成された返信文</li>
        <li>決済に関する情報(Stripe社が管理するものを含みます)</li>
        <li>サービス利用状況(生成回数等のログ)</li>
      </ul>

      <h2 className="mt-6 mb-2 font-bold">2. 利用目的</h2>
      <ul className="ml-5 list-disc">
        <li>本サービスの提供・運営・改善のため</li>
        <li>お問い合わせへの対応のため</li>
        <li>利用料金の請求・決済管理のため</li>
        <li>利用規約に違反する行為への対応のため</li>
        <li>新機能・サービス内容の変更等のお知らせのため</li>
      </ul>

      <h2 className="mt-6 mb-2 font-bold">3. 第三者提供</h2>
      <p>
        本サービスは、法令に基づく場合を除き、お客様の同意なく個人情報を
        第三者に提供することはありません。ただし、以下のような外部サービスに
        必要な範囲で情報を共有する場合があります。
      </p>
      <ul className="ml-5 list-disc">
        <li>Supabase(データベース・認証基盤)</li>
        <li>Stripe(決済処理)</li>
        <li>Anthropic(AIによる返信文生成。クチコミ本文等が送信されます)</li>
      </ul>

      <h2 className="mt-6 mb-2 font-bold">4. クチコミ・返信文の取り扱い</h2>
      <p>
        返信文の生成にあたり、入力されたクチコミ本文をAI(Anthropic社のAPI)へ
        送信します。送信された内容は、返信文生成の目的のみに利用されます。
      </p>

      <h2 className="mt-6 mb-2 font-bold">5. データの保管期間</h2>
      <p>
        お客様の情報は、アカウントが存在する期間中保管します。アカウント削除を
        希望される場合は、お問い合わせ窓口までご連絡ください。
      </p>

      <h2 className="mt-6 mb-2 font-bold">6. 安全管理</h2>
      <p>
        本サービスは、個人情報の漏えい、滅失または毀損の防止その他の個人情報の
        安全管理のために必要かつ適切な措置を講じます。
      </p>

      <h2 className="mt-6 mb-2 font-bold">7. プライバシーポリシーの変更</h2>
      <p>
        本ポリシーの内容は、お客様への事前の通知なく変更されることがあります。
        変更後のプライバシーポリシーは、本サービス上に掲載された時点で効力を
        生じるものとします。
      </p>

      <h2 className="mt-6 mb-2 font-bold">8. お問い合わせ</h2>
      <p>
        本ポリシーに関するお問い合わせは、
        <a href={buildContactMailto()} className="text-blue-600">
          {OPERATOR_EMAIL}
        </a>
        までご連絡ください。
      </p>

      <p className="mt-6 text-sm text-gray-500">制定日: 2026年6月11日</p>
    </>
  );
}
