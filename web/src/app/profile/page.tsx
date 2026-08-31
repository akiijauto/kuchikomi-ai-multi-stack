import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { INDUSTRIES } from "@/lib/constants";
import { ProfileForm } from "./profile-form";
import { BillingSection } from "./billing-section";
import { PurchaseTracker } from "./purchase-tracker";

export default async function ProfilePage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) {
    redirect("/login");
  }

  const { data: profile } = await supabase
    .from("profiles")
    .select("store_name, industry, tone, signature, plan")
    .eq("id", user.id)
    .single();

  return (
    <main className="mx-auto w-full max-w-xl px-4 py-8">
      <PurchaseTracker />
      {user.email && (
        <p className="mb-2 text-center text-xs text-gray-400">
          ログイン中: {user.email}
        </p>
      )}
      <header className="mb-8 text-center">
        <h1 className="text-2xl font-bold">お店のプロフィール</h1>
        <p className="mt-2 text-sm text-gray-500">
          ここで設定した内容をもとに、AIが「あなたのお店らしい」返信文を作成します。
        </p>
      </header>

      <div className="space-y-4">
        <BillingSection plan={(profile?.plan ?? "free") as "free" | "pro"} />

        <ProfileForm
          initial={{
            storeName: profile?.store_name ?? "",
            industry: profile?.industry || INDUSTRIES[0],
            tone: (profile?.tone ?? "polite") as "polite" | "friendly" | "casual",
            signature: profile?.signature ?? "",
          }}
        />
      </div>
    </main>
  );
}
