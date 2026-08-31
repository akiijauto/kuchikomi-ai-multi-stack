"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { LinkPending } from "./link-pending";

export function Header({
  storeName,
  userEmail,
}: {
  storeName: string;
  userEmail?: string;
}) {
  const router = useRouter();
  const [loggingOut, setLoggingOut] = useState(false);

  async function handleLogout() {
    setLoggingOut(true);
    try {
      const supabase = createClient();
      await supabase.auth.signOut();
      router.push("/login");
      router.refresh();
    } catch (e) {
      setLoggingOut(false);
      console.error(e);
    }
  }

  return (
    <div className="mb-4 flex items-center justify-between text-sm">
      <span className="font-medium text-gray-700">
        {storeName || "未設定の店舗"}
        {userEmail && (
          <span className="ml-2 font-normal text-gray-400">{userEmail}</span>
        )}
      </span>
      <div className="flex gap-3">
        <Link href="/profile" className="text-blue-600">
          プロフィール設定
          <LinkPending />
        </Link>
        <button
          type="button"
          onClick={handleLogout}
          disabled={loggingOut}
          className="text-gray-500 disabled:opacity-50"
        >
          {loggingOut ? "ログアウト中…" : "ログアウト"}
        </button>
      </div>
    </div>
  );
}
