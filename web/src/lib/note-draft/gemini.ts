import type { NoteOptionRecommendation, NoteOptionsResult } from "./types";

// コスト最小のFlash-Liteを使用(壁打ち用途と同じ採用理由: 戦略/README.md参照)
const GEMINI_MODEL = process.env.GEMINI_MODEL || "gemini-2.5-flash-lite";

const RECOMMENDATION_SCHEMA = {
  type: "object",
  properties: {
    recommendations: {
      type: "array",
      items: {
        type: "object",
        properties: {
          angle: { type: "string" },
          reason: { type: "string" },
          targetReader: { type: "string" },
          tone: { type: "string", enum: ["polite", "friendly", "casual"] },
        },
        required: ["angle", "reason", "targetReader", "tone"],
      },
    },
  },
  required: ["recommendations"],
} as const;

export async function recommendNoteOptions(
  theme: string,
): Promise<NoteOptionsResult> {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    return { recommendations: mockRecommendations(theme), mock: true };
  }

  const prompt = `あなたはnote(日本のブログプラットフォーム)で集客記事を書く編集者です。
クチコミ返信AI(美容室・サロン・飲食店向けの口コミ返信文をAIが自動作成する月額制Webサービス)の集客記事のテーマが与えられます。
note・SEOで読まれやすい記事にするための「方向性」を3つ提案してください。

各方向性には以下を含めること:
- angle: 記事の切り口・見出し構成の方向性(具体的に)
- reason: なぜこの切り口がnote/SEOで効果的か(一言)
- targetReader: 想定読者(業種・悩みを具体的に)
- tone: 文体("polite"=丁寧 / "friendly"=フレンドリー / "casual"=カジュアル のいずれか)

テーマ: ${theme}`;

  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${apiKey}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0.6,
          responseMimeType: "application/json",
          responseSchema: RECOMMENDATION_SCHEMA,
        },
      }),
    },
  );

  if (!res.ok) {
    throw new Error(`Gemini API error: ${res.status}`);
  }
  const data = await res.json();
  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) {
    throw new Error("Gemini APIからの応答が空でした");
  }
  const parsed = JSON.parse(text) as {
    recommendations: NoteOptionRecommendation[];
  };
  return { recommendations: parsed.recommendations, mock: false };
}

/** APIキー未設定の開発環境向けデモ提案 */
function mockRecommendations(theme: string): NoteOptionRecommendation[] {
  return [
    {
      angle: `「${theme}」の具体例をコピペで使えるテンプレ集として構成(デモ)`,
      reason: "「○○ 例文」系のSEOキーワードは検索ニーズが安定して高い",
      targetReader: "口コミ返信に毎回時間がかかっている美容室・飲食店オーナー",
      tone: "polite",
    },
    {
      angle: `「${theme}」を失敗談ベースで構成(デモ)`,
      reason: "失敗談は感情移入されやすくSNSでの拡散・滞在時間が伸びやすい",
      targetReader: "口コミ対応で過去に炎上・クレームを経験した店長",
      tone: "friendly",
    },
    {
      angle: `「${theme}」をチェックリスト形式で構成(デモ)`,
      reason: "チェックリストは保存・再訪されやすく記事の資産価値が高い",
      targetReader: "口コミ運用を体系化したい複数店舗展開中のオーナー",
      tone: "casual",
    },
  ];
}
