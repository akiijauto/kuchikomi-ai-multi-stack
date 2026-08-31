import type { NoteOptionsResult } from "./types";

const GEMINI_MODEL = process.env.GEMINI_MODEL || "gemini-2.5-flash-lite";

export async function suggestTheme(): Promise<{ theme: string; mock: boolean }> {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    return { theme: mockTheme(), mock: true };
  }

  const prompt = `クチコミ返信AI(美容室・サロン・飲食店向けの月額制Webサービス)のnote集客記事として、
「この記事があったら読みたい」という記事テーマを1つだけ、日本語で提案してください。

条件:
- テーマは短く簡潔に(15文字以内)
- note/SEOで読まれやすいテーマ
- 美容室・飲食店オーナーが実際に困っている悩みに基づいたテーマ
- テーマだけを出力(説明や理由は不要)

例:「低評価口コミへの返信例文」「放置された口コミへの返信テンプレ」「炎上しない口コミ返信の5ステップ」`;

  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${apiKey}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: { temperature: 0.7, maxOutputTokens: 50 },
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
  return { theme: text.trim(), mock: false };
}

/** APIキー未設定の開発環境向けデモテーマ */
function mockTheme(): string {
  const themes = [
    "低評価口コミへの返信例文(デモ)",
    "放置された口コミへの返信テンプレ(デモ)",
    "炎上しない口コミ返信の5ステップ(デモ)",
    "Google口コミが増える返信の工夫(デモ)",
    "時間がない店長向け・返信時短術(デモ)",
  ];
  return themes[Math.floor(Math.random() * themes.length)];
}
