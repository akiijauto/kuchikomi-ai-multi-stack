"use client";

import { useState } from "react";
import type {
  NoteOptionRecommendation,
  NoteDraftResult,
} from "@/lib/note-draft/types";

const TONE_LABELS: Record<NoteOptionRecommendation["tone"], string> = {
  polite: "丁寧",
  friendly: "フレンドリー",
  casual: "カジュアル",
};

export function NoteDraftForm() {
  const [theme, setTheme] = useState("");
  const [recommendations, setRecommendations] = useState<
    NoteOptionRecommendation[]
  >([]);
  const [selectedIndex, setSelectedIndex] = useState<number | null>(null);
  const [draft, setDraft] = useState<NoteDraftResult | null>(null);
  const [loadingStep, setLoadingStep] = useState<
    "recommend" | "draft" | "suggest" | null
  >(null);
  const [error, setError] = useState("");
  const [copied, setCopied] = useState(false);

  async function handleSuggestTheme() {
    setError("");
    setLoadingStep("suggest");
    try {
      const res = await fetch("/api/note-draft/suggest-theme", {
        method: "POST",
      });
      const data = await res.json();
      if (!res.ok) {
        setError(data.error ?? "テーマの提案に失敗しました");
        return;
      }
      setTheme(data.theme);
    } catch {
      setError("通信に失敗しました");
    } finally {
      setLoadingStep(null);
    }
  }

  async function handleRecommend() {
    setError("");
    if (theme.trim().length < 2) {
      setError("テーマを入力してください(2文字以上)");
      return;
    }
    setLoadingStep("recommend");
    setRecommendations([]);
    setSelectedIndex(null);
    setDraft(null);
    try {
      const res = await fetch("/api/note-draft/recommend", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ theme: theme.trim() }),
      });
      const data = await res.json();
      if (!res.ok) {
        setError(data.error ?? "提案の生成に失敗しました");
        return;
      }
      setRecommendations(data.recommendations);
    } catch {
      setError("通信に失敗しました");
    } finally {
      setLoadingStep(null);
    }
  }

  async function handleGenerateDraft() {
    if (selectedIndex === null) {
      setError("方向性を1つ選んでください");
      return;
    }
    setError("");
    setLoadingStep("draft");
    setDraft(null);
    const selected = recommendations[selectedIndex];
    try {
      const res = await fetch("/api/note-draft/generate", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          theme: theme.trim(),
          angle: selected.angle,
          targetReader: selected.targetReader,
          tone: selected.tone,
        }),
      });
      const data = await res.json();
      if (!res.ok) {
        setError(data.error ?? "生成に失敗しました");
        return;
      }
      setDraft(data);
    } catch {
      setError("通信に失敗しました");
    } finally {
      setLoadingStep(null);
    }
  }

  async function handleCopy() {
    if (!draft) return;
    await navigator.clipboard.writeText(`${draft.title}\n\n${draft.body}`);
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
  }

  return (
    <>
      <section className="mb-6 rounded-xl border border-gray-200 p-4">
        <h2 className="mb-3 text-sm font-semibold text-gray-700">
          記事テーマ
        </h2>
        <div className="mb-3 flex gap-2">
          <input
            value={theme}
            onChange={(e) => setTheme(e.target.value)}
            placeholder="例: 低評価口コミへの返信例文"
            maxLength={200}
            className="flex-1 rounded-lg border border-gray-300 px-3 py-2 text-sm"
          />
          <button
            type="button"
            onClick={handleSuggestTheme}
            disabled={loadingStep !== null}
            title="AIがテーマを自動提案します"
            className="rounded-lg border border-gray-300 px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-50"
          >
            {loadingStep === "suggest" ? "…" : "✨"}
          </button>
        </div>
        <button
          type="button"
          onClick={handleRecommend}
          disabled={loadingStep !== null}
          className="w-full rounded-xl bg-gray-800 py-2.5 text-sm font-semibold text-white disabled:opacity-50"
        >
          {loadingStep === "recommend" ? "提案中…" : "方向性を提案する"}
        </button>
      </section>

      {error && (
        <p className="mb-4 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-600">
          {error}
        </p>
      )}

      {recommendations.length > 0 && (
        <section className="mb-6 space-y-3">
          <h2 className="text-sm font-semibold text-gray-700">
            方向性を選んでください
          </h2>
          {recommendations.map((rec, i) => (
            <label
              key={i}
              className={`block cursor-pointer rounded-xl border p-4 ${
                selectedIndex === i
                  ? "border-blue-500 bg-blue-50"
                  : "border-gray-200"
              }`}
            >
              <div className="mb-1 flex items-center gap-2">
                <input
                  type="radio"
                  name="angle"
                  checked={selectedIndex === i}
                  onChange={() => setSelectedIndex(i)}
                />
                <span className="rounded-full bg-gray-100 px-2 py-0.5 text-xs font-medium text-gray-600">
                  {TONE_LABELS[rec.tone]}
                </span>
              </div>
              <p className="text-sm font-medium text-gray-900">{rec.angle}</p>
              <p className="mt-1 text-xs text-gray-500">理由: {rec.reason}</p>
              <p className="mt-1 text-xs text-gray-500">
                想定読者: {rec.targetReader}
              </p>
            </label>
          ))}
          <button
            type="button"
            onClick={handleGenerateDraft}
            disabled={loadingStep !== null || selectedIndex === null}
            className="w-full rounded-xl bg-blue-600 py-3 font-semibold text-white disabled:opacity-50"
          >
            {loadingStep === "draft"
              ? "下書き作成中…(数十秒お待ちください)"
              : "この方向性で下書きを作成する"}
          </button>
        </section>
      )}

      {draft && (
        <section className="rounded-xl border border-gray-200 p-4">
          {draft.mock && (
            <p className="mb-3 rounded-lg bg-amber-50 px-3 py-2 text-xs text-amber-700">
              デモモードで動作中です(AI APIキー未設定のため定型文を表示しています)
            </p>
          )}
          <div className="mb-2 flex items-center justify-between">
            <h2 className="text-sm font-semibold text-gray-700">下書き</h2>
            <button
              type="button"
              onClick={handleCopy}
              className="rounded-lg border border-gray-300 px-3 py-1 text-xs font-medium"
            >
              {copied ? "✓ コピーしました" : "コピー"}
            </button>
          </div>
          <p className="mb-2 font-bold text-gray-900">{draft.title}</p>
          <p className="whitespace-pre-wrap text-sm leading-relaxed text-gray-800">
            {draft.body}
          </p>
        </section>
      )}
    </>
  );
}
