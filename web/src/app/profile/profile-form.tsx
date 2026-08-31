"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import type { StoreProfile } from "@/lib/generation/types";
import { TONE_LABELS } from "@/lib/generation/types";
import { INDUSTRIES } from "@/lib/constants";
import { LinkPending } from "../link-pending";

const TONES = Object.entries(TONE_LABELS) as [
  StoreProfile["tone"],
  string,
][];

export function ProfileForm({ initial }: { initial: StoreProfile }) {
  const router = useRouter();
  const [storeName, setStoreName] = useState(initial.storeName);
  const [industry, setIndustry] = useState(initial.industry);
  const [tone, setTone] = useState(initial.tone);
  const [signature, setSignature] = useState(initial.signature ?? "");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [saved, setSaved] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setSaved(false);
    if (!storeName.trim()) {
      setError("店名を入力してください");
      return;
    }
    setSaving(true);
    try {
      const res = await fetch("/api/profile", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          storeName: storeName.trim(),
          industry,
          tone,
          signature: signature.trim() || undefined,
        }),
      });
      const data = await res.json();
      if (!res.ok) {
        setError(data.error ?? "保存に失敗しました");
        return;
      }
      setSaved(true);
      router.refresh();
    } catch {
      setError("通信に失敗しました。電波の良い場所でお試しください");
    } finally {
      setSaving(false);
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div className="rounded-xl border border-gray-200 p-4">
        <div className="space-y-3">
          <input
            type="text"
            value={storeName}
            onChange={(e) => setStoreName(e.target.value)}
            placeholder="店名(例: ヘアサロン ルーチェ)"
            maxLength={50}
            className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
          />
          <div className="flex gap-2">
            <select
              value={industry}
              onChange={(e) => setIndustry(e.target.value)}
              className="flex-1 rounded-lg border border-gray-300 px-3 py-2 text-sm"
            >
              {INDUSTRIES.map((i) => (
                <option key={i} value={i}>
                  {i}
                </option>
              ))}
            </select>
            <select
              value={tone}
              onChange={(e) =>
                setTone(e.target.value as StoreProfile["tone"])
              }
              className="flex-1 rounded-lg border border-gray-300 px-3 py-2 text-sm"
            >
              {TONES.map(([value, label]) => (
                <option key={value} value={value}>
                  口調: {label}
                </option>
              ))}
            </select>
          </div>
          <input
            type="text"
            value={signature}
            onChange={(e) => setSignature(e.target.value)}
            placeholder="署名(任意。例: 店長 山田)"
            maxLength={30}
            className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
          />
        </div>
      </div>

      {error && (
        <p className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-600">
          {error}
        </p>
      )}
      {saved && (
        <p className="rounded-lg bg-green-50 px-3 py-2 text-sm text-green-700">
          保存しました
        </p>
      )}

      <button
        type="submit"
        disabled={saving}
        className="w-full rounded-xl bg-blue-600 py-3 font-semibold text-white disabled:opacity-50"
      >
        {saving ? "保存中…" : "保存する"}
      </button>

      <Link
        href="/"
        className="block text-center text-sm text-blue-600"
      >
        返信文の作成に戻る
        <LinkPending />
      </Link>
    </form>
  );
}
