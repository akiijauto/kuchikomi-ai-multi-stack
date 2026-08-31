import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { NoteDraftForm } from "./note-draft-form";

export default async function NoteDraftPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  return (
    <main className="mx-auto w-full max-w-2xl px-4 py-8">
      <header className="mb-8 text-center">
        <h1 className="text-2xl font-bold">note下書き生成</h1>
        <p className="mt-2 text-sm text-gray-500">
          記事テーマを入力すれば、AIがnote向けの下書きを作成します。
          <br />
          投稿はnote.comで手動で行ってください。
        </p>
      </header>
      <NoteDraftForm />
    </main>
  );
}
