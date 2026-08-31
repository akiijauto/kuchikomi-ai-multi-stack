import Anthropic from "@anthropic-ai/sdk";
import { reviewReplyTemplate } from "./templates/review-reply";
import type {
  GeneratedReply,
  GenerationResult,
  ReviewReplyInput,
  StoreProfile,
} from "./types";

// コスト調整はオーナー判断で環境変数から切替(例: claude-haiku-4-5)
const MODEL = process.env.GENERATION_MODEL || "claude-sonnet-4-6";

const REPLY_SCHEMA = {
  type: "object",
  properties: {
    replies: {
      type: "array",
      items: {
        type: "object",
        properties: {
          label: { type: "string" },
          text: { type: "string" },
        },
        required: ["label", "text"],
        additionalProperties: false,
      },
    },
  },
  required: ["replies"],
  additionalProperties: false,
} as const;

export async function generateReviewReplies(
  profile: StoreProfile,
  input: ReviewReplyInput,
): Promise<GenerationResult> {
  if (!process.env.ANTHROPIC_API_KEY) {
    return { replies: mockReplies(profile, input), mock: true };
  }

  const client = new Anthropic();
  const response = await client.messages.create({
    model: MODEL,
    max_tokens: 2048,
    thinking: { type: "disabled" },
    output_config: {
      effort: "low",
      format: { type: "json_schema", schema: REPLY_SCHEMA },
    },
    system: reviewReplyTemplate.buildSystemPrompt(profile),
    messages: [
      { role: "user", content: reviewReplyTemplate.buildUserPrompt(input) },
    ],
  });

  const textBlock = response.content.find((b) => b.type === "text");
  if (!textBlock || textBlock.type !== "text") {
    throw new Error("生成結果が空でした");
  }
  const parsed = JSON.parse(textBlock.text) as { replies: GeneratedReply[] };
  const replies = profile.signature
    ? parsed.replies.map((r) => ({
        ...r,
        text: `${r.text}\n\n${profile.signature}`,
      }))
    : parsed.replies;
  return { replies, mock: false };
}

/** APIキー未設定の開発環境向けデモ返信 */
function mockReplies(
  profile: StoreProfile,
  input: ReviewReplyInput,
): GeneratedReply[] {
  const sig = profile.signature ? `\n${profile.signature}` : "";
  const isLow = input.rating <= 2;
  if (isLow) {
    return [
      {
        label: "誠実な謝罪(デモ)",
        text: `この度はご不快な思いをさせてしまい、誠に申し訳ございませんでした。いただいたご指摘を真摯に受け止め、スタッフ一同サービスの改善に努めてまいります。${sig}`,
      },
      {
        label: "改善姿勢を強調(デモ)",
        text: `貴重なご意見をありがとうございます。ご指摘いただいた点について早急に見直しを行っております。もし機会をいただけましたら、改善した${profile.storeName}をご体験いただけますと幸いです。${sig}`,
      },
      {
        label: "簡潔(デモ)",
        text: `この度は申し訳ございませんでした。いただいたお言葉を改善に活かしてまいります。${sig}`,
      },
    ];
  }
  return [
    {
      label: "標準(デモ)",
      text: `この度はご来店と温かい口コミをありがとうございます。お楽しみいただけたようで、スタッフ一同大変嬉しく思います。またのご来店を心よりお待ちしております。${sig}`,
    },
    {
      label: "再来店を促す(デモ)",
      text: `嬉しい口コミをありがとうございます!${profile.storeName}では季節ごとに新しいメニューもご用意しております。次回のご来店もぜひお楽しみにいらしてください。${sig}`,
    },
    {
      label: "簡潔(デモ)",
      text: `ご来店と口コミ投稿、ありがとうございます。またお会いできる日を楽しみにしております。${sig}`,
    },
  ];
}
