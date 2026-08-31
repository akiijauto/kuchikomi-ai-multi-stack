import Anthropic from "@anthropic-ai/sdk";
import type { NoteDraftInput, NoteDraftResult } from "./types";

const MODEL = process.env.GENERATION_MODEL || "claude-sonnet-4-6";

const TONE_INSTRUCTIONS = {
  polite: "敬語を基本とした、誠実で落ち着いた文体。",
  friendly: "丁寧さを保ちつつ、親しみやすく温かい文体。",
  casual: "読者に話しかけるような砕けた文体。ただし礼儀は保つ。",
} as const;

const DRAFT_SCHEMA = {
  type: "object",
  properties: {
    title: { type: "string" },
    body: { type: "string" },
  },
  required: ["title", "body"],
  additionalProperties: false,
} as const;

export async function generateNoteDraft(
  input: NoteDraftInput,
): Promise<NoteDraftResult> {
  if (!process.env.ANTHROPIC_API_KEY) {
    return { ...mockDraft(input), mock: true };
  }

  const client = new Anthropic();
  const response = await client.messages.create({
    model: MODEL,
    max_tokens: 4096,
    thinking: { type: "disabled" },
    output_config: {
      effort: "medium",
      format: { type: "json_schema", schema: DRAFT_SCHEMA },
    },
    system: `あなたはnote(日本のブログプラットフォーム)向けの集客記事を書く編集者です。
クチコミ返信AI(美容室・サロン・飲食店向けの口コミ返信文をAIが自動作成する月額制Webサービス)の集客記事の下書きをMarkdownで作成します。

# 文体
${TONE_INSTRUCTIONS[input.tone]}

# 記事のルール
- 見出し(##)を使った読みやすい構成にする
- 想定読者の悩みに具体的に寄り添う書き出しにする
- 断定しすぎず、誇大な効果は書かない(医療・薬機法的な表現は避ける)
- 記事の最後に「クチコミ返信AI」への導線(リンクはプレースホルダ "https://kuchikomi-ai-six.vercel.app/" を使う)を入れる
- これは下書きであり、人間が公開前に必ず確認・編集する前提なので、断定的な数値・実績は書かない`,
    messages: [
      {
        role: "user",
        content: `以下の条件で記事の下書きを作成してください。

テーマ: ${input.theme}
記事の方向性: ${input.angle}
想定読者: ${input.targetReader}`,
      },
    ],
  });

  const textBlock = response.content.find((b) => b.type === "text");
  if (!textBlock || textBlock.type !== "text") {
    throw new Error("生成結果が空でした");
  }
  const parsed = JSON.parse(textBlock.text) as { title: string; body: string };
  return { ...parsed, mock: false };
}

/** APIキー未設定の開発環境向けデモ下書き */
function mockDraft(input: NoteDraftInput): Omit<NoteDraftResult, "mock"> {
  return {
    title: `(デモ)${input.theme}`,
    body: `> これはデモモードの下書きです(ANTHROPIC_API_KEY未設定)。\n\n## はじめに\n\n${input.targetReader}向けに「${input.angle}」という方向性で記事を作成する想定です。\n\n## 本文(デモ)\n\nここに本文が入ります。\n\n## おわりに\n\nクチコミ返信AIはこちら → https://kuchikomi-ai-six.vercel.app/`,
  };
}
