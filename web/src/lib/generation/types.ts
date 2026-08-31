export type Tone = "polite" | "friendly" | "casual";

export const TONE_LABELS: Record<Tone, string> = {
  polite: "丁寧",
  friendly: "フレンドリー",
  casual: "カジュアル",
};

export interface StoreProfile {
  storeName: string;
  industry: string;
  tone: Tone;
  signature?: string;
}

export interface ReviewReplyInput {
  reviewText: string;
  rating: 1 | 2 | 3 | 4 | 5;
}

export interface GeneratedReply {
  label: string;
  text: string;
}

export interface GenerationResult {
  replies: GeneratedReply[];
  /** APIキー未設定時のデモ生成かどうか */
  mock: boolean;
}

/**
 * 生成テンプレートの共通インターフェース。
 * 第2弾(求人票改善)以降のプロダクトは、このインターフェースを実装した
 * テンプレートを追加するだけで同じエンジン・UI基盤に載せられる。
 */
export interface GenerationTemplate<TInput> {
  id: string;
  buildSystemPrompt(profile: StoreProfile): string;
  buildUserPrompt(input: TInput): string;
}
