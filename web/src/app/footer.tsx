import Link from "next/link";

export function Footer() {
  return (
    <footer className="mt-auto border-t border-gray-200 py-6 text-center text-xs text-gray-400">
      <nav className="flex flex-wrap justify-center gap-4">
        <Link href="/legal/tokushoho">特定商取引法に基づく表記</Link>
        <Link href="/legal/terms">利用規約</Link>
        <Link href="/legal/privacy">プライバシーポリシー</Link>
      </nav>
    </footer>
  );
}
