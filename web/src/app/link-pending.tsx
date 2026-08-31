"use client";

import { useLinkStatus } from "next/link";

// Link遷移中であることを示すインラインスピナー。Linkの子要素として使う。
export function LinkPending() {
  const { pending } = useLinkStatus();
  if (!pending) return null;
  return (
    <span
      aria-hidden
      className="ml-2 inline-block h-3 w-3 animate-spin rounded-full border-2 border-current border-t-transparent align-[-2px]"
    />
  );
}
