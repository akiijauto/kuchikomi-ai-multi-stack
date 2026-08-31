"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { trackSignUp } from "@/lib/analytics";

type Mode = "login" | "signup";

export default function LoginPage() {
  const router = useRouter();
  const [mode, setMode] = useState<Mode>("login");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setMessage("");
    setLoading(true);
    const supabase = createClient();

    if (mode === "login") {
      const { error } = await supabase.auth.signInWithPassword({
        email,
        password,
      });
      if (error) {
        setError("メールアドレスまたはパスワードが正しくありません");
        setLoading(false);
        return;
      }
      // 成功時はページ遷移するため、loadingは解除しない(解除すると遷移完了前に
      // ボタン表示が「ログイン」に戻って見えてしまう)。
      router.push("/");
      router.refresh();
    } else {
      const { data, error } = await supabase.auth.signUp({
        email,
        password,
        options: {
          emailRedirectTo: `${window.location.origin}/auth/callback`,
        },
      });
      if (error) {
        setError(
          error.message.includes("Password")
            ? "パスワードは6文字以上で入力してください"
            : "登録に失敗しました。入力内容をご確認ください",
        );
        setLoading(false);
        return;
      }
      if (data.session) {
        // 新規登録の初回コンバージョン。セッション確立(登録完了)時のみ撃つ。
        // Confirm email=ONになっても、確認待ち状態では発火しない。
        trackSignUp();
        router.push("/");
        router.refresh();
        return;
      }
      setMessage(
        "確認メールを送信しました。メール内のリンクをクリックして登録を完了してください。",
      );
      setLoading(false);
    }
  }

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-sm flex-col justify-center px-4 py-8">
      <h1 className="mb-1 text-center text-2xl font-bold">クチコミ返信AI</h1>
      <p className="mb-8 text-center text-sm text-gray-500">
        {mode === "login" ? "ログイン" : "新規登録(無料)"}
      </p>

      <form onSubmit={handleSubmit} className="space-y-3">
        <input
          type="email"
          required
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          placeholder="メールアドレス"
          className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
        />
        <input
          type="password"
          required
          minLength={6}
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          placeholder="パスワード(6文字以上)"
          className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
        />

        {error && (
          <p className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-600">
            {error}
          </p>
        )}
        {message && (
          <p className="rounded-lg bg-green-50 px-3 py-2 text-sm text-green-700">
            {message}
          </p>
        )}

        <button
          type="submit"
          disabled={loading}
          className="w-full rounded-xl bg-blue-600 py-3 font-semibold text-white disabled:opacity-50"
        >
          {loading
            ? "処理中…"
            : mode === "login"
              ? "ログイン"
              : "無料で登録する"}
        </button>
      </form>

      <button
        type="button"
        onClick={() => {
          setMode(mode === "login" ? "signup" : "login");
          setError("");
          setMessage("");
        }}
        className="mt-4 text-center text-sm text-blue-600"
      >
        {mode === "login"
          ? "アカウントをお持ちでない方はこちら"
          : "すでにアカウントをお持ちの方はこちら"}
      </button>
    </main>
  );
}
