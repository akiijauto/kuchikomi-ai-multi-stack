"use client";

import { useState } from "react";
import { PLAN_LABELS, type Plan } from "@/lib/plans";

export function BillingSection({ plan }: { plan: Plan }) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function handleClick() {
    setError("");
    setLoading(true);
    try {
      const endpoint = plan === "free" ? "/api/stripe/checkout" : "/api/stripe/portal";
      const res = await fetch(endpoint, { method: "POST" });
      const data = await res.json();
      if (!res.ok || !data.url) {
        setError(data.error ?? "処理に失敗しました");
        return;
      }
      window.location.href = data.url;
    } catch {
      setError("通信に失敗しました。電波の良い場所でお試しください");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="rounded-xl border border-gray-200 p-4">
      <p className="mb-3 text-sm text-gray-700">
        現在のプラン:{" "}
        <span className="font-semibold">{PLAN_LABELS[plan]}</span>
      </p>
      {plan === "free" && (
        <p className="mb-3 text-xs text-gray-500">
          プロプラン(月額980円)では月300件まで生成でき、トーンカスタマイズや返信履歴保存もご利用いただけます。
        </p>
      )}
      {error && (
        <p className="mb-3 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-600">
          {error}
        </p>
      )}
      <button
        type="button"
        onClick={handleClick}
        disabled={loading}
        className="w-full rounded-xl bg-gray-900 py-3 font-semibold text-white disabled:opacity-50"
      >
        {loading
          ? "処理中…"
          : plan === "free"
            ? "プロプランにアップグレード(月980円)"
            : "お支払い情報を管理する"}
      </button>
    </div>
  );
}
