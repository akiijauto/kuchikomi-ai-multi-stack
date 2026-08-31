import Link from "next/link";

export default function LegalLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <main className="mx-auto w-full max-w-2xl px-4 py-8">
      <Link href="/" className="mb-6 inline-block text-sm text-blue-600">
        ← トップへ戻る
      </Link>
      <article className="prose prose-sm max-w-none whitespace-pre-wrap text-gray-800">
        {children}
      </article>
    </main>
  );
}
