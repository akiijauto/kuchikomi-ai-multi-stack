import { createClient as createSupabaseClient } from "@supabase/supabase-js";

/**
 * RLSを無視できる管理者クライアント。
 * Stripe Webhookなど、ユーザーセッションを持たないサーバー処理専用。
 */
export function createAdminClient() {
  return createSupabaseClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { persistSession: false } },
  );
}
