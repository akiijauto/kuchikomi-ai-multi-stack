"use client";

import { useEffect, useRef, useState } from "react";
import type { GeneratedReply } from "@/lib/generation/types";

export function GenerateForm({
  initialUsed,
  limit,
}: {
  initialUsed: number;
  limit: number;
}) {
  const [reviewText, setReviewText] = useState("");
  const [rating, setRating] = useState(5);
  const [replies, setReplies] = useState<GeneratedReply[]>([]);
  const [isMock, setIsMock] = useState(false);
  const [used, setUsed] = useState(initialUsed);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [copiedIndex, setCopiedIndex] = useState<number | null>(null);
  const [statusMessage, setStatusMessage] = useState<{
    text: string;
    type: "success" | "error";
  } | null>(null);
  const copyTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    return () => {
      if (copyTimerRef.current) {
        clearTimeout(copyTimerRef.current);
      }
    };
  }, []);

  async function handleGenerate() {
    if (copyTimerRef.current) {
      clearTimeout(copyTimerRef.current);
      copyTimerRef.current = null;
    }
    setCopiedIndex(null);
    setError("");
    setStatusMessage(null);
    if (reviewText.trim().length < 5) {
      setError("口コミ本文を入力してください(5文字以上)");
      return;
    }
    setLoading(true);
    setReplies([]);
    setIsMock(false);
    try {
      const res = await fetch("/api/generate", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          review: { reviewText: reviewText.trim(), rating },
        }),
      });
      const data = await res.json();
      if (!res.ok) {
        setError(data.error ?? "生成に失敗しました");
        return;
      }
      setReplies(data.replies);
      setIsMock(data.mock);
      if (data.usage) {
        setUsed(data.usage.used);
      }
      if (data.replies?.length) {
        setStatusMessage({
          text: `✓ 返信案を${data.replies.length}件作成しました`,
          type: "success",
        });
      }
    } catch {
      setError("通信に失敗しました。電波の良い場所でお試しください");
    } finally {
      setLoading(false);
    }
  }

  async function handleCopy(text: string, index: number) {
    if (copyTimerRef.current) {
      clearTimeout(copyTimerRef.current);
      copyTimerRef.current = null;
    }
    try {
      await navigator.clipboard.writeText(text);
      setCopiedIndex(index);
      setStatusMessage({ text: "✓ 返信文をコピーしました", type: "success" });
      copyTimerRef.current = setTimeout(() => {
        setCopiedIndex(null);
        setStatusMessage(null);
        copyTimerRef.current = null;
      }, 1500);
    } catch {
      setCopiedIndex(null);
      setStatusMessage({
        text: "コピーに失敗しました。文章を長押しして選択し、コピーしてください",
        type: "error",
      });
      copyTimerRef.current = setTimeout(() => {
        setStatusMessage(null);
        copyTimerRef.current = null;
      }, 3000);
    }
  }

  function handleBack() {
    if (copyTimerRef.current) {
      clearTimeout(copyTimerRef.current);
      copyTimerRef.current = null;
    }
    setReplies([]);
    setReviewText("");
    setRating(5);
    setCopiedIndex(null);
    setError("");
    setStatusMessage(null);
    setIsMock(false);
    window.scrollTo({ top: 0, behavior: "smooth" });
  }

  const remaining = Math.max(limit - used, 0);

  return (
    <>
      <p className="mb-4 text-right text-xs text-gray-500">
        今月の残り利用回数: {remaining} / {limit}件
      </p>

      <section className="mb-6 rounded-xl border border-gray-200 p-4">
        <h2 className="mb-3 text-sm font-semibold text-gray-700">
          届いた口コミ
        </h2>
        <div className="mb-3 flex items-center gap-1">
          <span className="mr-2 text-sm text-gray-600">評価:</span>
          {[1, 2, 3, 4, 5].map((star) => (
            <button
              key={star}
              type="button"
              onClick={() => setRating(star)}
              aria-label={`星${star}つ`}
              className={`text-2xl ${star <= rating ? "text-amber-400" : "text-gray-300"}`}
            >
              ★
            </button>
          ))}
        </div>
        <textarea
          value={reviewText}
          onChange={(e) => setReviewText(e.target.value)}
          placeholder="口コミ本文をここに貼り付けてください"
          rows={5}
          maxLength={2000}
          className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
        />
      </section>

      {error && (
        <p className="mb-4 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-600">
          {error}
        </p>
      )}

      <button
        type="button"
        onClick={handleGenerate}
        disabled={loading || remaining <= 0}
        className="w-full rounded-xl bg-blue-600 py-3 font-semibold text-white disabled:opacity-50"
      >
        {loading ? "作成中…(10秒ほどお待ちください)" : "返信文を作成する"}
      </button>

      {statusMessage && (
        <p
          role="status"
          aria-live="polite"
          className={`mt-3 rounded-lg px-3 py-2 text-xs ${
            statusMessage.type === "success"
              ? "bg-green-50 text-green-700"
              : "bg-red-50 text-red-600"
          }`}
        >
          {statusMessage.text}
        </p>
      )}

      {isMock && replies.length > 0 && (
        <p className="mt-4 rounded-lg bg-amber-50 px-3 py-2 text-xs text-amber-700">
          デモモードで動作中です(AI APIキー未設定のため定型文を表示しています)
        </p>
      )}

      {replies.length > 0 && (
        <section className="mt-6 space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-sm font-semibold text-gray-700">
              返信案(タップしてコピー)
            </h2>
            <button
              type="button"
              onClick={handleBack}
              className="text-xs font-medium text-blue-600"
            >
              ← 新しい口コミを入力する
            </button>
          </div>
          {replies.map((reply, i) => (
            <div key={i} className="rounded-xl border border-gray-200 p-4">
              <div className="mb-2 flex items-center justify-between">
                <span className="rounded-full bg-blue-50 px-2 py-0.5 text-xs font-medium text-blue-700">
                  {reply.label}
                </span>
                <button
                  type="button"
                  onClick={() => handleCopy(reply.text, i)}
                  className="rounded-lg border border-gray-300 px-3 py-1 text-xs font-medium"
                >
                  {copiedIndex === i ? "✓ コピーしました" : "コピー"}
                </button>
              </div>
              <p className="whitespace-pre-wrap text-sm leading-relaxed text-gray-800">
                {reply.text}
              </p>
            </div>
          ))}
        </section>
      )}
    </>
  );
}
