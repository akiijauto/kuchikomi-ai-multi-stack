export interface NoteOptionRecommendation {
  /** 見出し案(タイトルそのものではなく方向性) */
  angle: string;
  /** なぜこの方向性が良いかの一言 */
  reason: string;
  /** 想定読者 */
  targetReader: string;
  tone: "polite" | "friendly" | "casual";
}

export interface NoteOptionsResult {
  recommendations: NoteOptionRecommendation[];
  /** Gemini APIキー未設定時のデモ生成かどうか */
  mock: boolean;
}

export interface NoteDraftInput {
  theme: string;
  angle: string;
  targetReader: string;
  tone: "polite" | "friendly" | "casual";
}

export interface NoteDraftResult {
  title: string;
  body: string;
  /** Anthropic APIキー未設定時のデモ生成かどうか */
  mock: boolean;
}
