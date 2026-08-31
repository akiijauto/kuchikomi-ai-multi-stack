import type { ReactNode } from "react";
import { OPERATOR_EMAIL, buildContactMailto } from "@/lib/contact";

export const metadata = {
  title: "特定商取引法に基づく表記 | クチコミ返信AI",
};

const FALLBACK = "ご請求をいただいた場合、遅滞なく開示いたします";

const ROWS: { label: string; value: ReactNode }[] = [
  {
    label: "販売事業者",
    value: process.env.NEXT_PUBLIC_OPERATOR_NAME || "(未設定)",
  },
  {
    label: "運営責任者",
    value: process.env.NEXT_PUBLIC_OPERATOR_NAME || "(未設定)",
  },
  {
    label: "所在地",
    value: process.env.NEXT_PUBLIC_OPERATOR_ADDRESS || FALLBACK,
  },
  {
    label: "電話番号",
    value: process.env.NEXT_PUBLIC_OPERATOR_PHONE || FALLBACK,
  },
  {
    label: "メールアドレス",
    value: (
      <a href={buildContactMailto()} className="text-blue-600">
        {OPERATOR_EMAIL}
      </a>
    ),
  },
  {
    label: "販売価格",
    value:
      "プロプラン 月額980円(税込)。詳細は各プランのご案内ページに記載します。",
  },
  {
    label: "商品代金以外の必要料金",
    value: "インターネット接続にかかる通信費はお客様のご負担となります。",
  },
  {
    label: "お支払い方法",
    value: "クレジットカード決済(Stripe社の決済システムを利用)",
  },
  {
    label: "お支払い時期",
    value:
      "ご登録時に初回課金が行われ、以後は毎月同日に自動課金されます。",
  },
  {
    label: "サービス提供時期",
    value: "決済完了後、直ちにご利用いただけます。",
  },
  {
    label: "返品・キャンセルについて",
    value:
      "本サービスの性質上、提供後の返金は致しかねます。解約はマイページから" +
      "いつでも行うことができ、解約後も当該請求期間の終了までご利用いただけます。",
  },
];

export default function TokushohoPage() {
  return (
    <>
      <h1 className="mb-6 text-xl font-bold">特定商取引法に基づく表記</h1>

      <table className="w-full border-collapse text-sm">
        <tbody>
          {ROWS.map((row) => (
            <tr key={row.label} className="border-b border-gray-200">
              <th className="w-1/3 py-3 pr-4 text-left align-top font-medium text-gray-600">
                {row.label}
              </th>
              <td className="py-3 align-top">{row.value}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </>
  );
}
