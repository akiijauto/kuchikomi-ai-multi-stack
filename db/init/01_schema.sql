-- ※このファイルは web/supabase/schema.sql の複製。変更は必ず本体側で行い、
--   `cp web/supabase/schema.sql db/init/01_schema.sql` で反映する。
-- クチコミ返信AI: 会員プロフィール・利用回数管理
-- Supabaseダッシュボードの「SQL Editor」でこのファイルの内容を実行してください。

-- 1. 店舗プロフィール(会員登録時に自動で行が作成される)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  store_name text not null default '',
  industry text not null default '',
  tone text not null default 'polite' check (tone in ('polite', 'friendly', 'casual')),
  signature text not null default '',
  plan text not null default 'free' check (plan in ('free', 'pro')),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "Users can view own profile" on public.profiles;
create policy "Users can view own profile"
  on public.profiles for select
  using (auth.uid() = id);

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id);

-- 利用者が更新できる列をプロフィール4列のみに制限する。
-- plan / stripe_* は課金情報で、正規の更新経路はStripe Webhook(service_role)のみ。
-- 列単位の権限がないと、利用者がブラウザからSupabase APIを直接叩いて
-- 自分の plan を 'pro' に書き換えられてしまう(無課金でのプラン昇格)。
revoke update on public.profiles from anon, authenticated;
grant update (store_name, industry, tone, signature) on public.profiles to authenticated;

-- 2. 新規会員登録時にプロフィール行を自動作成
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id) values (new.id);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 3. 月間利用回数(プラン別の生成回数制限に使用)
create table if not exists public.usage_logs (
  user_id uuid not null references auth.users(id) on delete cascade,
  month text not null, -- 'YYYY-MM'
  count int not null default 0,
  primary key (user_id, month)
);

alter table public.usage_logs enable row level security;

drop policy if exists "Users can view own usage" on public.usage_logs;
create policy "Users can view own usage"
  on public.usage_logs for select
  using (auth.uid() = user_id);

-- 4. プラン別の月間利用上限(上限値の正本。DB側の強制はこのテーブルを参照する)
-- ※ web/src/lib/plans.ts の PLAN_LIMITS は画面表示・エラー文言用の複製。
--    上限を変更するときは必ず両方を同じ値に更新すること。
create table if not exists public.plan_limits (
  plan text primary key,
  monthly_limit int not null check (monthly_limit > 0)
);

insert into public.plan_limits (plan, monthly_limit) values
  ('free', 5),
  ('pro', 300)
on conflict (plan) do update set monthly_limit = excluded.monthly_limit;

-- 利用者が直接読み書きする必要はないため全面拒否(RLS有効+ポリシーなし+権限剥奪)。
-- 参照するのは下の increment_usage(security definer)だけ。
alter table public.plan_limits enable row level security;
revoke all on public.plan_limits from anon, authenticated;

-- 5. 利用回数の上限チェック付き加算関数(生成APIから呼び出す)
-- 上限チェックと加算を1つのSQL文で行うため、同時に複数リクエストが来ても
-- 上限を超えて加算されることはない。上限超過時は例外を返す。
-- 上限値は引数で受け取らず、呼び出した本人の profiles.plan から関数内で決める。
-- (SupabaseのRPCは利用者がブラウザから直接呼べるため、引数で受け取る設計だと
--  上限値を任意の値に偽装して呼ばれる余地が残る。関数内で決めればその余地がない)
-- 旧シグネチャが残っている環境では先に削除する(再実行しても冪等)。
drop function if exists public.increment_usage(text);      -- 旧: 上限チェックなし版(再実行時は現行版)
drop function if exists public.increment_usage(text, int); -- 旧: 上限を引数で受け取る版

create function public.increment_usage(p_month text)
returns int
language plpgsql
security definer set search_path = public
as $$
declare
  v_limit int;
  new_count int;
begin
  select pl.monthly_limit into v_limit
  from public.profiles p
  join public.plan_limits pl on pl.plan = p.plan
  where p.id = auth.uid();

  -- 未ログイン・プロフィール行なし・未知のプランなど、上限を決められない場合は加算を拒否
  if v_limit is null then
    raise exception 'USAGE_PLAN_NOT_FOUND' using errcode = 'P0002';
  end if;

  insert into public.usage_logs (user_id, month, count)
  values (auth.uid(), p_month, 1)
  on conflict (user_id, month)
  do update set count = usage_logs.count + 1
  where usage_logs.count < v_limit
  returning count into new_count;

  -- 既存行が上限に達していた場合は更新されず new_count が null になる。
  -- 新規行(count=1)が上限を超えるケースは例外で挿入ごとロールバックされる。
  if new_count is null or new_count > v_limit then
    -- API側は SQLSTATE 'P0001' で上限超過を判定する(メッセージ文字列に依存しない)
    raise exception 'USAGE_LIMIT_EXCEEDED' using errcode = 'P0001';
  end if;

  return new_count;
end;
$$;

-- 6. Stripe連携用カラム(課金実装に伴い追加。既存テーブルにも反映可能)
alter table public.profiles add column if not exists stripe_customer_id text;
alter table public.profiles add column if not exists stripe_subscription_id text;
